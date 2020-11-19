#!/bin/bash

increment_version() {
 local v=$1
 if [ -z $2 ]; then
    local rgx='^((?:[0-9]+\.)*)([0-9]+)($)'
 else
    local rgx='^((?:[0-9]+\.){'$(($2-1))'})([0-9]+)(\.|$)'
    for (( p=`grep -o "\."<<<".$v"|wc -l`; p<$2; p++)); do
       v+=.0; done; fi
 val=`echo -e "$v" | perl -pe 's/^.*'$rgx'.*$/$2/'`
 echo "$v" | perl -pe s/$rgx.*$'/${1}'`printf %0${#val}s $(($val+1))`/
}

options=$(getopt v:t $*)
tagging=0
eval set -- "$options"
while true; do
    case "$1" in
    -v)
        version="$2"; shift;
        shift
        ;;
    -t)
        echo "Tagging enabled";
        tagging=1
        shift
        ;;
    --)
        shift; break;;
    esac
done

cloudsmith=$(which cloudsmith)
if [ ! -x $cloudsmith ]; then
  echo "please install cloudsmith first"
  echo "pip install --upgrade cloudsmith-cli && cloudsmith token"
  exit 1
fi

name=$(grep ^name Chart.yaml | awk '{print $2}')
if [ "$version" == "" ]; then
  version=$(grep ^version Chart.yaml | awk '{print $2}')
fi

if [ "$version" != "$(grep ^version Chart.yaml | awk '{print $2}')" ]; then
  sed -i .bak "s/version:.*/version: $version/g" Chart.yaml
fi

if [ $tagging -eq 1 ]; then
  version=$(increment_version $version)
  sed -i .bak "s/version:.*/version: $version/g" Chart.yaml
fi

docker run --rm -ti \
  -v $(pwd):/workdir \
  docker.digitalis.io/docker-repo/helm:latest \
  helm package .

cloudsmith push helm axonops/helm $name-$version.tgz

rm -f $name-$version.tgz *.bak

git tag $version && git push --tags
