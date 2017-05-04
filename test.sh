#!/usr/bin/env bash

set -o errexit

echo 'Building test jar...'
mvn -q clean package -f test/pom.xml
find . -name '*.iso' -type f -print0 | xargs -0 java -jar test/target/test.jar 0.6.5.9
