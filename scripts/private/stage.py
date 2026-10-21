"""Private PHP 5 staging: immutable plans, packages, native tests and signed readiness."""
import hashlib
import hmac
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
from store import Store, canonical, digest, fingerprint, prefix, require, workdir

ROOT = Path(__file__).resolve().parents[2]
PROJECT = json.loads((Path(__file__).parent / 'project.json').read_text())
VERSIONS = {'5.3':'5.3.29', '5.4':'5.4.45', '5.5':'5.5.38'}


def context():
    project = PROJECT['project']
    require(os.environ['PRIVATE_PROJECT'] == project, 'Project mismatch')
    require(os.environ['GITHUB_REPOSITORY'] == 'shivammathur/' + project, 'Repository mismatch')
    require(re.fullmatch('[a-f0-9]{40}', os.environ['GITHUB_SHA']), 'Invalid revision')
    require(os.environ['GITHUB_REF'] in ('refs/heads/main', 'refs/heads/feature/private-r2-releases'), 'Unapproved ref')
    return project, prefix(project, os.environ['PRIVATE_BUILD_ID'])


def matrices(project):
    if project == 'php5-ubuntu':
        builds = [{'id': arch, 'arch': arch, 'runner': runner} for arch, runner in
                  [('x86_64','ubuntu-24.04'), ('arm64','ubuntu-24.04-arm')]]
        tests = [{'id': osname, 'runner': osname, 'arch': arch} for arch, runners in
                 [('x86_64',['ubuntu-22.04','ubuntu-24.04','ubuntu-26.04']),
                  ('arm64',['ubuntu-22.04-arm','ubuntu-24.04-arm','ubuntu-26.04-arm'])] for osname in runners]
    else:
        builds = [{'id': arch, 'arch': arch, 'runner': runner, 'macports_package': package} for arch, runner, package in
                  [('arm64','macos-14','MacPorts-2.12.6-14-Sonoma.pkg'),
                   ('x86_64','macos-15-intel','MacPorts-2.12.6-15-Sequoia.pkg')]]
        tests = [{'id': runner, 'runner': runner, 'arch': arch} for arch, runners in
                 [('arm64',['macos-14','macos-15','macos-26']), ('x86_64',['macos-15-intel'])] for runner in runners]
    return builds, tests


def source_check(file, source, extract=None):
    require(fingerprint(file) == {k:source[k] for k in ('sha256','bytes')}, 'Source digest mismatch')
    root = source['root']
    require(re.fullmatch(r'[A-Za-z0-9_.-]+',root) and root not in ('.','..'), 'Invalid source root')
    seen, total, header, configure = set(), 0, None, False
    with tarfile.open(file) as archive:
        members = archive.getmembers()
        for item in members:
            parts = PurePosixPath(item.name).parts
            require(parts and parts[0] == root and '..' not in parts and not item.name.startswith('/'), 'Unsafe source path')
            require(item.name not in seen and (item.isfile() or item.isdir()), 'Duplicate/special source entry')
            seen.add(item.name); total += item.size
            require(total < 2 * 1024**3 and len(seen) < 100000, 'Oversized source')
            if item.name == root + '/main/php_version.h':
                require(item.size < 65536, 'Invalid version header')
                header = archive.extractfile(item).read().decode()
            if item.name == root + '/buildconf':
                configure = item.isfile() and bool(item.mode & 0o111)
        require(configure and header and re.search(r'^#define PHP_VERSION "' + re.escape(source['version']) + r'"$', header, re.M), 'Source version/bootstrap mismatch')
        if extract:
            archive.extractall(extract, members=members, filter='data')
    return len(seen)


def names(plan, arch):
    suffix = '-arm64' if arch == 'arm64' else ''
    minor = plan['minor']
    if plan['project'] == 'php5-darwin':
        short = minor.replace('.','')
        return [f'php{short}{suffix}-cache.tar.zst',f'php{short}-imagick{suffix}-cache.tar.zst']
    return [f'php-{minor}-build{suffix}.tar.zst', f'php-{minor}{suffix}.tar.xz', f'php-{minor}{suffix}.tar.zst']


def plan():
    project, base = context()
    minor = os.environ['PHP_VERSION']
    require(minor in VERSIONS, 'Unsupported minor')
    key = os.environ['PRIVATE_SOURCE_MANIFEST_KEY']
    require(key.startswith('uploads/manifests/') and re.fullmatch(r'uploads/manifests/[a-f0-9]{64}\.json',key), 'Invalid source manifest key')
    store = Store(); manifest = store.get_json(key)
    require(hashlib.sha256(canonical(manifest)).hexdigest() == Path(key).stem, 'Manifest identity mismatch')
    source = next(s for s in manifest['files'] if s['version'] == VERSIONS[minor])
    require(source['name'] == 'php-' + VERSIONS[minor] + '.tar.gz', 'Source name mismatch')
    require(re.fullmatch('[a-f0-9]{64}', source['sha256']) and 0 < source['bytes'] < 256 * 1024**2, 'Invalid source descriptor')
    require(source['key'] == f"uploads/sha256/{source['sha256']}/{source['name']}", 'Invalid immutable source key')
    file = workdir() / source['name']; store.get(source['key'],file,{k:source[k] for k in ('sha256','bytes')})
    source_check(file, source)
    builds, tests = matrices(project)
    record = {'schema':1, 'project':project, 'id':os.environ['PRIVATE_BUILD_ID'], 'repository':os.environ['GITHUB_REPOSITORY'],
              'revision':os.environ['GITHUB_SHA'], 'ref':os.environ['GITHUB_REF'], 'minor':minor, 'source':source,
              'source_manifest_key':key, 'dependencies':PROJECT['dependencies'], 'builds':builds, 'tests':tests,
              'installer':fingerprint(ROOT/'scripts/install.sh'), 'public_publication':False}
    store.put_json(base + '/plan.json',record)
    with open(os.environ['GITHUB_OUTPUT'],'a') as f:
        f.write('builds=' + json.dumps({'include':builds}) + '\n')
        f.write('tests=' + json.dumps({'include':tests}) + '\n')


def load():
    project, base = context()
    plan = Store().get_json(base + '/plan.json')
    require(plan['project'] == project and plan['id'] == os.environ['PRIVATE_BUILD_ID'] and
            plan['revision'] == os.environ['GITHUB_SHA'] and plan['ref'] == os.environ['GITHUB_REF'], 'Plan identity mismatch')
    require(plan['builds'] == matrices(project)[0] and plan['tests'] == matrices(project)[1] and
            plan['dependencies'] == PROJECT['dependencies'] and plan['source']['version'] == VERSIONS[plan['minor']], 'Plan drift')
    return plan, base


def clean_env():
    env = {k:v for k,v in os.environ.items() if not (k.startswith('PRIVATE_') or k in
          ('GH_TOKEN','GITHUB_TOKEN','ACTIONS_RUNTIME_TOKEN','ACTIONS_ID_TOKEN_REQUEST_TOKEN','ACTIONS_ID_TOKEN_REQUEST_URL'))}
    # File-command paths have already been isolated by the supervisor.
    return env


def shell(command, env):
    subprocess.run(command, env=env, check=True, umask=0o022)


def checkout(destination):
    destination.mkdir()
    archive = workdir() / 'checkout.tar'
    with archive.open('wb') as f:
        subprocess.run(['git','archive',os.environ['GITHUB_SHA']],cwd=ROOT,stdout=f,check=True)
    with tarfile.open(archive) as t:
        t.extractall(destination, filter='data')
    return destination


def diagnostics(store, base, label, directory):
    if not directory.exists():
        return
    output = workdir() / (label + '-diagnostics.tar.gz')
    with tarfile.open(output,'w:gz') as t:
        t.add(directory,arcname='diagnostics',recursive=True)
    store.put(base + '/diagnostics/' + output.name,output)


def build():
    plan, base = load(); store=Store()
    item = next(i for i in plan['builds'] if i['id'] == os.environ['PRIVATE_JOB_ID'])
    task=workdir()/'build'; task.mkdir(); output=task/'packages'; output.mkdir(); reports=task/'reports';reports.mkdir()
    source = task/plan['source']['name']; store.get(plan['source']['key'],source,{k:plan['source'][k] for k in ('sha256','bytes')})
    source_check(source,plan['source'])
    guard=plan['source']['mitigation_patch']
    require(re.fullmatch('[a-f0-9]{64}',guard['sha256']) and guard['key']==f"uploads/patches/{guard['sha256']}.patch", 'Invalid mitigation proof')
    mitigation=task/'mitigation.patch'; store.get(guard['key'],mitigation,{k:guard[k] for k in ('sha256','bytes')})
    repo=checkout(task/'repository')
    env={**clean_env(), 'PHP_VERSION':plan['minor'], 'PHP_FULL_VERSION':plan['source']['version'],
         'SOURCE_ARCHIVE':str(source), 'SOURCE_SHA256':plan['source']['sha256'], 'SOURCE_ROOT':plan['source']['root'], 'MITIGATION_PATCH':str(mitigation), 'EXPECTED_ARCHITECTURE':item['arch'],
         'OUTPUT_DIR':str(output), 'REPORT_DIR':str(reports), 'BUILD_REPOSITORY':str(repo),
         'PRIVATE_TASK_DIR':str(task), 'DEPENDENCY_CONFIG':str(ROOT/'scripts/private/project.json')}
    if 'macports_package' in item:env['MACPORTS_PACKAGE']=item['macports_package']
    try:
        shell(['bash',str(ROOT/'scripts/private/build.sh')],env)
        require(sorted(p.name for p in output.iterdir()) == sorted(names(plan,item['arch'])), 'Incomplete/unexpected packages')
        files=[]
        for name in names(plan,item['arch']):
            file=output/name
            record={'name':name,**fingerprint(file),'key':base+'/packages/'+item['arch']+'/'+name}
            store.put(record['key'],file);files.append(record)
        result={'schema':1,'id':item['id'],'plan_sha256':digest(plan),'status':'success','files':files}
        store.put_json(base+'/results/build-'+item['id']+'.json',result)
    finally:
        diagnostics(store,base,'build-'+item['id'],reports)


def package_result(plan, base, arch):
    result=Store().get_json(base+'/results/build-'+arch+'.json')
    require(result['id'] == arch and result['plan_sha256'] == digest(plan) and result['status'] == 'success', 'Invalid package result')
    require(sorted(f['name'] for f in result['files']) == sorted(names(plan,arch)), 'Incomplete package inventory')
    for f in result['files']:
        require(f['key'] == base+'/packages/'+arch+'/'+f['name'] and re.fullmatch('[a-f0-9]{64}',f['sha256']) and 0 < f['bytes'] < 2*1024**3,'Invalid package descriptor')
    return result


def test():
    plan, base=load();store=Store()
    item=next(i for i in plan['tests'] if i['id'] == os.environ['PRIVATE_JOB_ID'])
    result=package_result(plan,base,item['arch'])
    task=workdir()/'test';task.mkdir();packages=task/'packages';packages.mkdir();reports=task/'reports';reports.mkdir()
    for f in result['files']:store.get(f['key'],packages/f['name'],{k:f[k] for k in ('sha256','bytes')})
    env={**clean_env(),'PHP_VERSION':plan['minor'],'PHP_FULL_VERSION':plan['source']['version'],
         'EXPECTED_ARCHITECTURE':item['arch'],'PACKAGE_DIR':str(packages),'REPORT_DIR':str(reports),'PRIVATE_TASK_DIR':str(task)}
    try:
        shell(['bash',str(ROOT/'scripts/private/test.sh')],env)
        store.put_json(base+'/results/test-'+item['id']+'.json',{'schema':1,'id':item['id'],'plan_sha256':digest(plan),
                       'package_sha256':digest(result),'status':'success','runner':item['runner']})
    finally:
        diagnostics(store,base,'test-'+item['id'],reports)


def ready():
    plan,base=load();store=Store()
    packages=[package_result(plan,base,i['arch']) for i in plan['builds']]
    tests=[]
    for item in plan['tests']:
        result=store.get_json(base+'/results/test-'+item['id']+'.json')
        require(result == {'schema':1,'id':item['id'],'plan_sha256':digest(plan),'status':'success','runner':item['runner'],
                           'package_sha256':digest(next(p for p in packages if p['id']==item['arch']))},'Unverified test result')
        tests.append(result)
    key=os.environ['PRIVATE_RELEASE_SIGNING_KEY'];require(re.fullmatch('[a-f0-9]{64}',key),'Invalid signing key')
    payload={'plan':plan,'packages':packages,'tests':tests,'release_approved':False}
    record={'payload':payload,'signature':hmac.new(bytes.fromhex(key),canonical(payload),hashlib.sha256).hexdigest()}
    store.put_json(base+'/ready.json',record)

if __name__ == '__main__':
    {'plan':plan,'build':build,'test':test,'ready':ready}[sys.argv[1]]()
