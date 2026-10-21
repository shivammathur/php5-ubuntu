"""Offline checks for private-source and evidence boundaries."""
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import stage
from store import prefix, fingerprint

class Contracts(unittest.TestCase):
    def test_matrices(self):
        for project,count in [('php5-ubuntu',6),('php5-darwin',4)]:
            builds,tests=stage.matrices(project)
            self.assertEqual({x['arch'] for x in builds},{'arm64','x86_64'})
            self.assertEqual(len(tests),count)
            self.assertEqual(len({x['id'] for x in tests}),count)
    def test_run_attempt_identity(self):
        self.assertEqual(prefix('php5-ubuntu','123-2'),'php5-ubuntu/builds/123-2')
        for value in ('../1','123','0-1','1-0'):
            with self.assertRaises(ValueError):prefix('php5-ubuntu',value)
    def test_source_identity_and_archive_escape(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'source.tar.gz'
            def archive(extra):
                with tarfile.open(p,'w:gz') as t:
                    for name,data,mode in [('root/main/php_version.h',b'#define PHP_VERSION "5.3.29"\n',0o644),('root/buildconf',b'#!/bin/sh\n',0o755)]+extra:
                        m=tarfile.TarInfo(name);m.size=len(data);m.mode=mode;t.addfile(m,io.BytesIO(data))
                return {'root':'root','version':'5.3.29',**fingerprint(p)}
            source=archive([]);self.assertEqual(stage.source_check(p,source),2)
            with self.assertRaises(ValueError):stage.source_check(p,{**source,'version':'5.4.45'})
            source=archive([('root/../../escape',b'bad',0o644)])
            with self.assertRaises(ValueError):stage.source_check(p,source)
    def test_build_children_do_not_receive_credentials(self):
        with patch.dict(os.environ,{'PRIVATE_R2_SECRET_ACCESS_KEY':'not-a-real-key','GH_TOKEN':'not-a-token','GITHUB_TOKEN':'not-a-token','ACTIONS_RUNTIME_TOKEN':'not-a-token'}):
            env=stage.clean_env()
            for key in ('PRIVATE_R2_SECRET_ACCESS_KEY','GH_TOKEN','GITHUB_TOKEN','ACTIONS_RUNTIME_TOKEN'):self.assertNotIn(key,env)
    def test_package_contract(self):
        for minor in stage.VERSIONS:
            for arch in ('arm64','x86_64'):
                self.assertEqual(len(stage.names({'project':'php5-ubuntu','minor':minor},arch)),3)
                self.assertEqual(len(stage.names({'project':'php5-darwin','minor':minor},arch)),2)
    def test_no_public_storage_actions(self):
        workflow=(stage.ROOT/'.github/workflows/stage-private.yml').read_text()
        for forbidden in ('actions/upload-artifact','actions/cache','contents: write','gh release','cloudsmith'):
            self.assertNotIn(forbidden,workflow)
        self.assertIn('persist-credentials: false',workflow)
        self.assertIn('PRIVATE_RELEASE_SIGNING_KEY',workflow)

if __name__=='__main__':unittest.main()
