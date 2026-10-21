<?php
function check($condition, $message) { if (!$condition) { throw new Exception($message); } }
foreach (array('curl','gd','gmp','intl','mbstring','mysqli','openssl','pdo_mysql','pdo_sqlite','soap','sockets','sqlite3','tidy','xmlrpc','xsl','zip') as $extension) {
    check(extension_loaded($extension), 'Missing extension: '.$extension);
}
$db = new SQLite3(':memory:'); check($db->querySingle('SELECT 2 + 3') === 5, 'SQLite failed');
check(gmp_strval(gmp_add('2', '3')) === '5', 'GMP failed');
check(imagecreatetruecolor(2, 2) !== false, 'GD failed');
check(gzuncompress(gzcompress('private smoke')) === 'private smoke', 'zlib failed');
$file = tempnam(sys_get_temp_dir(), 'zip'); unlink($file); $zip = new ZipArchive();
check($zip->open($file, ZipArchive::CREATE) === true && $zip->addFromString('test', 'ok') && $zip->close(), 'ZIP failed'); unlink($file);
$xml = new DOMDocument(); check($xml->loadXML('<root/>'), 'XML failed');
check(openssl_digest('test', 'sha256') === hash('sha256','test'), 'OpenSSL failed');
echo "Native module smoke passed\n";
