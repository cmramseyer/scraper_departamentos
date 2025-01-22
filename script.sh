#!/usr/bin/env bash
# para usar con cron, es necesario cargar RVM/RBENV
source ${RVM_PATH}
# tambien cargar la version correcta de ruby
rvm use ${SCRAPER_RUBY_VERSION} > /dev/null 2>&1
cd ${SCRAPER_FOLDER}
ruby departamentos.rb
