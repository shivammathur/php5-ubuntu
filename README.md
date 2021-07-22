# PHP5 for ubuntu

<a href="https://github.com/shivammathur/php5-ubuntu" title="php5 install scripts for ubuntu"><img alt="Build status" src="https://github.com/shivammathur/php5-ubuntu/workflows/Test/badge.svg"></a>
<a href="https://github.com/shivammathur/php5-ubuntu/blob/main/LICENSE" title="license"><img alt="LICENSE" src="https://img.shields.io/badge/license-MIT-428f7e.svg"></a>
<a href="https://github.com/shivammathur/php5-ubuntu#usage" title="Install builds"><img alt="PHP Versions Supported" src="https://img.shields.io/badge/php-5.3, 5.4 and 5.5-8892BF.svg"></a>

> Scripts to install end of life PHP versions.

PHP versions in this project have reached end of life, so only use this project in isolated environments like a container, also only for testing backward-compatibility. Do not use this in production.

The aim is to provide old PHP for GitHub Actions Ubuntu runners. You might need some more libraries if using this elsewhere.

## Usage

### PHP 5.3
```bash
curl -sSL https://github.com/shivammathur/php5-ubuntu/releases/latest/download/install.sh | bash -s 5.3
```

### PHP 5.4
```bash
curl -sSL https://github.com/shivammathur/php5-ubuntu/releases/latest/download/install.sh | bash -s 5.4
```

### PHP 5.5
```bash
curl -sSL https://github.com/shivammathur/php5-ubuntu/releases/latest/download/install.sh | bash -s 5.5
```

## License

- The code and documentation in this project is licensed under the [MIT license](LICENSE "License for shivammathur/php5-ubuntu").
- The library binaries have been sourced from [Ubuntu](https://packages.ubuntu.com/ "Ubuntu Packages Repository") package archive.
- This project has multiple [dependencies](#dependencies "Dependencies of shivammathur/php5-ubuntu"). Their licenses can be found in their respective repositories.

## Dependencies

- [Libraries](https://github.com/shivammathur/php5-ubuntu/tree/main/deps "Libraries for old PHP")
- [APCu](https://github.com/krakjoe/apcu "APCu PHP extension")
- [Imagick](https://github.com/Imagick/imagick "Imagick PHP extension")
- [PEAR](https://github.com/pear/pear-core "PEAR to install extensions")
- [PHP](https://github.com/php/php-src "PHP upstream")
- [PhpRedis](https://github.com/phpredis/phpredis "Redis PHP extension")
- [Xdebug](https://github.com/xdebug/xdebug "Xdebug PHP extension")
- [Zend OPCache](https://github.com/zendtech/ZendOptimizerPlus "Zend OPCache extension")
- [Zstandard](https://github.com/facebook/zstd "Zstandard compression algorithm")
