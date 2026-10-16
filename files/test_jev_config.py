import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from jev_config import JevConfig

def test_config():
    c=JevConfig(Path('x'))
    assert c.model_path.name.endswith('.gguf')
    assert c.command()[c.command().index('--host') + 1] == '127.0.0.1'
    print('backend config tests passed')
if __name__ == '__main__': test_config()
