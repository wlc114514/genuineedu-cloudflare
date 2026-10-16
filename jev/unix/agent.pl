#!/usr/bin/perl
# JEV local judging agent (macOS / Linux). Same HTTP protocol as jev/windows/agent.ps1.
#   agent.pl start   -> detach into the background, start llama-server, serve 127.0.0.1:8002
#   agent.pl stop    -> ask the running agent to stop; also clean up our own llama-server
#   agent.pl status  -> print the agent status JSON
# Started on demand by the jev:// protocol handler, never at login.
# Only core Perl modules are used, so the system perl that ships with macOS is enough.
use strict;
use warnings;
use IO::Socket::INET;
use IO::Select;
use POSIX qw(setsid WNOHANG);
use Fcntl qw(:flock);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Time::HiRes qw(time sleep);
use JSON::PP;

my $VERSION = '2.0.0';
my $BASE = dirname(abs_path($0));
my $JEV_DIR = "$BASE/jev";
my $LLAMA = "$JEV_DIR/llama/llama-server";
my $MODEL = 'Jev-Style-0.8B-Decision-v3-Q4_K_M.gguf';
my $LOG = "$BASE/agent.log";

my %cfg = (
  agentPorts => [8002, 18002, 28002],
  llamaPorts => [8001, 18001, 28001],
  allowedOrigins => ['https://genuineedu.pages.dev', 'https://*.genuineedu.pages.dev', 'http://localhost:*', 'http://127.0.0.1:*'],
  heartbeatTimeout => 90, byeGrace => 10, launchGrace => 120, errorLinger => 60,
  startupTimeout => 120, sleepIdle => 300, ctxSize => 2048,
);
if (open my $fh, '<', "$BASE/config.json") {
  local $/;
  my $j = eval { decode_json(<$fh>) };
  if (ref $j eq 'HASH') { $cfg{$_} = $j->{$_} for keys %$j; }
}

sub logmsg {
  my ($msg) = @_;
  if (-s $LOG && -s $LOG > 512 * 1024) { rename $LOG, "$LOG.old"; }
  if (open my $fh, '>>', $LOG) {
    my @t = localtime;
    printf $fh "%04d-%02d-%02d %02d:%02d:%02d [%d] %s\n", $t[5] + 1900, $t[4] + 1, @t[3, 2, 1, 0], $$, $msg;
    close $fh;
  }
}

sub http_get {
  my ($port, $path, $timeout) = @_;
  my $s = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $port, Proto => 'tcp', Timeout => $timeout || 1.5) or return;
  print $s "GET $path HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
  my $sel = IO::Select->new($s);
  my $buf = '';
  my $end = time + ($timeout || 1.5);
  while (time < $end && $sel->can_read($end - time)) {
    my $n = sysread($s, my $chunk, 8192);
    last unless $n;
    $buf .= $chunk;
  }
  close $s;
  return unless $buf =~ m{^HTTP/\d\.\d (\d+)};
  my $code = $1;
  my ($body) = $buf =~ /\r\n\r\n(.*)\z/s;
  return ($code, $body // '');
}

sub find_agent {
  for my $p (@{ $cfg{agentPorts} }) {
    my ($code, $body) = http_get($p, '/status');
    return ($p, $body) if $code && $code == 200 && $body =~ /"app"\s*:\s*"jev-agent"/;
  }
  return;
}

sub own_llama_pids {
  # Only llama-server processes started from OUR install dir.
  my @pids;
  open my $ps, '-|', 'ps', '-axo', 'pid=,command=' or return;
  while (my $line = <$ps>) {
    next unless $line =~ /^\s*(\d+)\s+(.*)$/;
    my ($pid, $cmd) = ($1, $2);
    next if $pid == $$;
    push @pids, $pid if index($cmd, "$LLAMA ") == 0;   # we always exec it by absolute path
  }
  close $ps;
  return @pids;
}

sub kill_own_llama {
  my @pids = own_llama_pids();
  return unless @pids;
  kill 'TERM', @pids;
  for (1 .. 30) { last unless grep { kill 0, $_ } @pids; sleep 0.1; }
  kill 'KILL', grep { kill 0, $_ } @pids;
  logmsg("killed llama-server @pids");
}

sub port_free {
  my ($port) = @_;
  my $c = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $port, Proto => 'tcp', Timeout => 0.3);
  if ($c) { close $c; return 0; }
  # ReuseAddr: a port that only has TIME_WAIT leftovers is free (live listeners were caught above)
  my $l = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $port, Proto => 'tcp', Listen => 1, ReuseAddr => 1) or return 0;
  close $l;
  return 1;
}

# ------------------------------------------------------------------ one-shot actions
my $action = lc($ARGV[0] // 'start');
$action = $action =~ /stop/ ? 'stop' : $action =~ /status/ ? 'status' : 'start';

if ($action eq 'status') {
  my ($p, $body) = find_agent();
  print $body ? "$body\n" : qq({"app":"jev-agent","state":"offline"}\n);
  exit($body ? 0 : 1);
}
if ($action eq 'stop') {
  my ($p) = find_agent();
  if ($p) { http_get($p, '/stop', 3); sleep 0.8; }
  kill_own_llama();
  exit 0;
}

# ------------------------------------------------------------------ start: background + single instance
unless ($ENV{JEV_FOREGROUND}) {
  defined(my $pid = fork) or die "fork: $!";
  exit 0 if $pid;
  setsid();
  defined($pid = fork) or exit 1;
  exit 0 if $pid;
}
chdir $BASE;
open STDIN, '<', '/dev/null';
open STDOUT, '>>', '/dev/null';
open STDERR, '>>', '/dev/null';

open my $lock, '>', "$BASE/agent.lock" or exit 1;
exit 0 unless flock($lock, LOCK_EX | LOCK_NB);

my ($listener, $agent_port);
for my $p (@{ $cfg{agentPorts} }) {
  $listener = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => $p, Proto => 'tcp', Listen => 16, ReuseAddr => 1);
  if ($listener) { $agent_port = $p; last; }
  logmsg("agent port $p busy");
}
exit 1 unless $listener;
$listener->blocking(0);
logmsg("agent $VERSION listening on $agent_port");

my $state = 'starting';
my $error = '';
my $state_at = time;
my $launch_at = time;
my $key = join '', map { sprintf '%02x', int(rand 256) } 1 .. 16;
my ($llama_pid, $llama_port) = (0, 0);
my %clients;
my $ever_seen = 0;
my $empty_since = 0;
my $quit = '';

sub set_state {
  ($state, $error) = @_;
  $error //= '';
  $state_at = time;
  logmsg("state=$state" . ($error ? " error=$error" : ''));
}

sub origin_allowed {
  my ($o) = @_;
  return 1 unless defined $o && length $o;
  for my $pat (@{ $cfg{allowedOrigins} }) {
    my $rx = quotemeta($pat);
    $rx =~ s/\\\*/[A-Za-z0-9-]+/g;
    return 1 if $o =~ /^$rx\z/;
  }
  return 0;
}

sub status_json {
  my %s = (app => 'jev-agent', version => $VERSION, state => $state, error => $error, clients => scalar(keys %clients) + 0);
  if ($state eq 'ready') {
    $s{llama} = { url => "http://127.0.0.1:$llama_port", key => $key };
    $s{key} = $key;
  }
  return JSON::PP->new->canonical->encode(\%s);
}

sub respond {
  my ($c, $code, $body, $origin) = @_;
  my %reason = (200 => 'OK', 204 => 'No Content', 400 => 'Bad Request', 403 => 'Forbidden', 404 => 'Not Found');
  my $h = "HTTP/1.1 $code $reason{$code}\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: " . length($body)
    . "\r\nCache-Control: no-store\r\nConnection: close\r\n";
  if ($origin && origin_allowed($origin)) {
    $h .= "Access-Control-Allow-Origin: $origin\r\nVary: Origin\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
      . "Access-Control-Allow-Headers: *\r\nAccess-Control-Allow-Private-Network: true\r\nAccess-Control-Max-Age: 600\r\n";
  }
  local $SIG{PIPE} = 'IGNORE';
  syswrite($c, "$h\r\n$body");
}

sub handle {
  my ($c) = @_;
  $c->blocking(1);
  my $sel = IO::Select->new($c);
  my $req = '';
  my $end = time + 1.5;
  while (time < $end && index($req, "\r\n\r\n") < 0 && length($req) < 65536) {
    last unless $sel->can_read($end - time);
    my $n = sysread($c, my $chunk, 8192);
    last unless $n;
    $req .= $chunk;
  }
  my ($method, $target) = $req =~ m{^(\S+)\s+(\S+)};
  unless ($method) { respond($c, 400, '{"error":"bad_request"}', ''); close $c; return; }
  my ($origin) = $req =~ /^origin:\s*(\S+)\s*$/mi;
  if (!origin_allowed($origin)) {
    logmsg("rejected origin $origin");
    respond($c, 403, '{"error":"origin_not_allowed"}', '');
    close $c;
    return;
  }
  if (uc $method eq 'OPTIONS') { respond($c, 204, '', $origin); close $c; return; }
  my ($path, $query) = split /\?/, $target, 2;
  my ($cid) = ($query // '') =~ /(?:^|&)c=([^&]*)/;
  $cid = 'anon' unless defined $cid && length $cid;
  $cid =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
  $cid = substr($cid, 0, 64);
  if ($path eq '/ping') {
    $clients{$cid} = time;
    $ever_seen = 1;
    respond($c, 200, status_json(), $origin);
  } elsif ($path eq '/status') {
    respond($c, 200, status_json(), $origin);
  } elsif ($path eq '/bye') {
    delete $clients{$cid};
    logmsg("bye from $cid");
    respond($c, 200, '{"ok":true}', $origin);
  } elsif ($path eq '/stop') {
    respond($c, 200, '{"ok":true}', $origin);
    $quit = 'stop requested';
  } else {
    respond($c, 404, '{"error":"not_found"}', $origin);
  }
  close $c;
}

sub start_llama {
  return set_state('error', 'llama_missing') unless -x $LLAMA;
  return set_state('error', 'model_missing') unless -f "$JEV_DIR/$MODEL";
  # Ports can be held for a moment (a process still exiting...): retry ~10 s before giving up.
  for my $try (0 .. 5) {
    sleep 2 if $try;
    for my $p (@{ $cfg{llamaPorts} }) {
      if (port_free($p)) { $llama_port = $p; last }
      logmsg("llama port $p busy");
    }
    last if $llama_port;
  }
  return set_state('error', 'port_busy') unless $llama_port;
  my $slog = "$JEV_DIR/server.log";
  unlink $slog if -s $slog && -s $slog > 2 * 1024 * 1024;
  my $pid = fork;
  return set_state('error', 'llama_start_failed') unless defined $pid;
  if ($pid == 0) {
    chdir $JEV_DIR;
    close $listener;
    open STDOUT, '>>', $slog;
    open STDERR, '>&', \*STDOUT;
    exec $LLAMA, '-m', $MODEL, '--host', '127.0.0.1', '--port', $llama_port, '-c', $cfg{ctxSize}, '--no-webui',
      '--api-key', $key, '--sleep-idle-seconds', $cfg{sleepIdle}
      or POSIX::_exit(127);
  }
  $llama_pid = $pid;
  logmsg("llama-server pid $pid on port $llama_port");
}

sub llama_healthy {
  my ($code, $body) = http_get($llama_port, '/health', 0.8);
  return $code && $code == 200 && $body =~ /"ok"/;
}

sub shutdown_all {
  my ($why) = @_;
  logmsg("shutting down: $why");
  if ($llama_pid && kill 0, $llama_pid) {
    kill 'TERM', $llama_pid;
    for (1 .. 30) { last if waitpid($llama_pid, WNOHANG) > 0; sleep 0.1; }
    kill 'KILL', $llama_pid if kill 0, $llama_pid;
  }
  close $listener if $listener;
  exit 0;
}

$SIG{TERM} = $SIG{INT} = $SIG{HUP} = sub { shutdown_all('signal') };

kill_own_llama();    # leftovers from a crashed agent
start_llama();

my $sel = IO::Select->new($listener);
my $last_check = 0;
while (!$quit) {
  if ($sel->can_read(0.2)) {
    while (my $c = $listener->accept) { handle($c); last if $quit; }
    next;
  }
  my $now = time;
  next if $now - $last_check < 0.5;
  $last_check = $now;

  if ($state ne 'error' && $llama_pid && waitpid($llama_pid, WNOHANG) > 0) {
    logmsg('llama-server exited with status ' . ($? >> 8));
    $llama_pid = 0;
    if ($state eq 'starting') { set_state('error', 'llama_exit') } else { $quit = 'llama-server exited' }
  } elsif ($state eq 'starting') {
    if (llama_healthy()) { set_state('ready') }
    elsif ($now - $state_at > $cfg{startupTimeout}) { set_state('error', 'startup_timeout') }
  }
  $quit = "error $error" if $state eq 'error' && $now - $state_at > $cfg{errorLinger};

  for my $id (keys %clients) {
    if ($now - $clients{$id} > $cfg{heartbeatTimeout}) { delete $clients{$id}; logmsg("client $id timed out"); }
  }
  if (%clients) { $empty_since = 0 }
  elsif ($ever_seen) {
    if (!$empty_since) { $empty_since = $now }
    elsif ($now - $empty_since > $cfg{byeGrace}) { $quit = 'all pages closed' }
  } elsif ($now - $launch_at > $cfg{launchGrace}) { $quit = 'no page connected' }
}
shutdown_all($quit);
