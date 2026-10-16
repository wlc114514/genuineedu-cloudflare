// JEV protocol handler (JScript, run by wscript.exe).
// Registered for jev:// links. Starts agent.ps1 with no visible window.
// The URL is never passed through: only the words start / stop are honoured.
var shell = new ActiveXObject('WScript.Shell');
var fso = new ActiveXObject('Scripting.FileSystemObject');
var base = fso.GetParentFolderName(WScript.ScriptFullName);
var arg = WScript.Arguments.length > 0 ? String(WScript.Arguments(0)) : 'start';
var action = /stop/i.test(arg) ? 'stop' : 'start';
// A PSModulePath inherited from PowerShell 7 breaks Windows PowerShell 5.1 cmdlets.
try { shell.Environment('PROCESS').Remove('PSModulePath'); } catch (e) { }
var ps = shell.ExpandEnvironmentStrings('%SystemRoot%') + '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
var cmd = '"' + ps + '" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + base + '\\agent.ps1" ' + action;
shell.Run(cmd, 0, false);
