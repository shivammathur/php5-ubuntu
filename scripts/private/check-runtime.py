import json,os,struct,sys
from pathlib import Path
root=Path(sys.argv[1]);arch=sys.argv[2];expected=183 if arch=='arm64' else 62
checked=[]
for p in root.rglob('*'):
 if p.is_symlink():continue
 assert not p.stat().st_mode & 0o022, 'Writable payload: '+str(p)
 if not p.is_file():continue
 with p.open('rb') as f:h=f.read(20)
 if h[:4]==b'\x7fELF':
  assert len(h)==20 and h[4]==2
  machine=int.from_bytes(h[18:20],'little' if h[5]==1 else 'big')
  assert machine==expected,(str(p),machine,expected)
  checked.append(str(p.relative_to(root)))
assert any(x=='bin/php' for x in checked) and any(x.endswith('.so') for x in checked)
print(json.dumps({'architecture':arch,'elf_files':checked,'permissions':'passed'},indent=2))
