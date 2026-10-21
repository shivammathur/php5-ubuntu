"""Construct a private Docker context, preserving the repository build stages."""
import os
from pathlib import Path
import re
import shutil
import json
import sys
r=Path(os.environ['BUILD_REPOSITORY']);minor=os.environ['PHP_VERSION']
p=r/'Dockerfile';s=p.read_text()
start=s.index('# Fetch php source\n');end=s.index('FROM build-deps AS build-prepare',start)
s=s[:start]+'''# Source was authenticated, validated and pinned by the private coordinator.
FROM base AS fetch-php
COPY private-input/source.tar.gz /tmp/php-build/packages/private-source.tar.gz

'''+s[end:]
s=s.replace('COPY --from=fetch-php /tmp/php-build/packages/php-*.tar.bz2 /tmp/php-build/packages/',
'''COPY --from=fetch-php /tmp/php-build/packages/private-source.tar.gz /tmp/php-build/packages/private-source.tar.gz
COPY private-input/mitigation.patch /tmp/php-build/packages/mitigation.patch
ENV PHP_PRIVATE_SOURCE_ARCHIVE=/tmp/php-build/packages/private-source.tar.gz
ARG PHP_PRIVATE_SOURCE_SHA256
ENV PHP_PRIVATE_SOURCE_SHA256=$PHP_PRIVATE_SOURCE_SHA256''')
p.write_text(s)
source=r/'private-input';source.mkdir();shutil.copyfile(os.environ['SOURCE_ARCHIVE'],source/'source.tar.gz')
shutil.copyfile(os.environ['MITIGATION_PATCH'],source/'mitigation.patch')
p=r/'scripts/clone-phpbuild.sh';s=p.read_text();pin=json.loads(Path(os.environ['DEPENDENCY_CONFIG']).read_text())['dependencies']['php_build_commit']
s=s.replace('cd ~/php-build && sudo ./install.sh', f'cd ~/php-build && git checkout --detach {pin} && sudo ./install.sh')
p.write_text(s)
p=r/'php-build/definitions'/minor;s=p.read_text()
s,n=re.subn(r'install_package "https://secure.php.net/distributions/php-[^"]+"',
'. /scripts/private/source.sh\ninstall_package_from_private',s)
assert n==1;s=s.replace('patch_file "php-5.3.29-64bit-intl.patch"', 'patch_file "php53-intl-buildconf.patch"')
p.write_text(s)
shutil.copyfile(r/'scripts/private/php53-intl-buildconf.patch', r/'php-build/patches/php53-intl-buildconf.patch')
# Fail on rejected patches; never continue after a partially applied distribution series.
p=r/'scripts/setup-phpbuild.sh';s=p.read_text();s+='\n'+r'''python - <<'CHECK'
p='/usr/local/bin/php-build'
s=open(p).read()
old='patch -d "$source_path" -N -p1 -s < $patch'
assert s.count(old)==1
s=s.replace(old, 'patch --batch --fuzz=0 -d "$source_path" -N -p1 < "$patch" || return 1')
s=s.replace('apply_patches "$source_path" 2>&4', 'apply_patches "$source_path" 2>&4\n    patch --force --fuzz=0 --dry-run -R -p1 -d "$source_path" < /tmp/php-build/packages/mitigation.patch')
open(p,'w').write(s)
CHECK
''';p.write_text(s)
