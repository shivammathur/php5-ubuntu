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

# Git exports require regenerated parsers. Bison 1.75 fails on these grammars;
# 2.6.4 is accepted by all three branch configure checks.
p=r/'scripts/build-deps.sh';text=p.read_text()
text=text.replace('bison-1.75','bison-2.6.4')
marker='  tar -xzf /tmp/bison.tar.gz -C /tmp'
assert text.count(marker)==1
text=text.replace(marker, '  echo "de2d15dfdcfc24405464cb95acc9d5ef31fb2e5be4aca6a530ec59bb57c30e5d  /tmp/bison.tar.gz" | sha256sum -c -\n'+marker)
p.write_text(text)

# Use the coordinator's hash-verified inputs. Legacy container TLS/PECL responses
# must never be mistaken for source tarballs, and versions remain unchanged.
extensions=Path(os.environ['PHP_EXTENSION_SOURCE_DIR'])
p=r/'scripts/build-extensions.sh';text=p.read_text()
versions=dict(re.findall(r"^([A-Z_]+)_VERSION='([^']+)'",text,re.M))
pattern=r'  curl -o /tmp/([a-z_]+).tgz -sL https://pecl.php.net/get/([a-z_]+)-"\$([A-Z_]+)_VERSION".tgz'
def local_extension(match):
    target,package,var=match.groups();name=package+'-'+versions[var]+'.tgz'
    assert (extensions/name).is_file(), 'Missing verified extension input: '+name
    return '  cp /private-extensions/'+name+' /tmp/'+target+'.tgz'
text,count=re.subn(pattern,local_extension,text);assert count==15
p.write_text(text);shutil.copytree(extensions,source/'extensions')
p=r/'Dockerfile';text=p.read_text();marker='FROM php-build AS build-extensions-prepare'
assert text.count(marker)==1
p.write_text(text.replace(marker,marker+'\nCOPY private-input/extensions/ /private-extensions/'))
