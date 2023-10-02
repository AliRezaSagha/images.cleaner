#!/bin/bash
SHORT=u:,p:,r:,k:,h
LONG=userName:,password:,releaseNumber:,keepTagCount:,help
OPTS=$(getopt -a -n images.cleaner.sh --options $SHORT --longoptions $LONG -- "$@")

eval set -- "$OPTS"

while :
do
  case $1 in
    -u | --userName )
      userName="$2"
      shift 2
      ;;
    -p | --password )
      password="$2"
      shift 2
      ;;
    -r | --releaseNumber )
      releaseNumber="$2"
      shift 2
      ;;
    -k | --keepTagCount )
      keepTagNum="$2"
      shift 2
      ;;
    -h | --help)
      "#usage -r releaseNumber -k keepTagCount"
      exit 2
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      ;;
  esac
done

# get the list of repositories names

repositories=$(curl -s -k -u $userName:$password -X 'GET'  "https://dockerrepo.tosanltd.com/api/v2.0/projects/docker/repositories?page=1&page_size=0" -H 'accept: application/json' | jq -r '.[]?'.name | awk '{gsub(/\//,"%252F",$0); print}' | awk '{gsub(/docker%252F/,"",$0); print}')

while IFS= read -r line; do
	echo "Repository: $line";
	
	# get the list of tags for each repository

	tags=$(curl -s -k -u $userName:$password -X 'GET'   "https://dockerrepo.tosanltd.com/api/v2.0/projects/docker/repositories/$line/artifacts?page=1&page_size=0&with_tag=true" -H 'accept: application/json' | jq '.[].tags[]?'.name| grep $releaseNumber | sort -rV $1 | awk '{print $1}' | tr -d '"');
	
	# get the list of keep tags for each repository

	keepTags=$(curl -s -k -u $userName:$password -X 'GET'   "https://dockerrepo.tosanltd.com/api/v2.0/projects/docker/repositories/$line/artifacts?page=1&page_size=0&with_tag=true" -H 'accept: application/json'  | jq '.[].tags[]?'.name|grep $releaseNumber | sort -rV $1 | awk '{print $1}' | tr -d '"' | head -$keepTagNum); 
  echo "Tags: $tags";
	echo "keepTags:$keepTags";
	for tag in $tags; do found=false;
		for keeptag in $keepTags; do
			if [[ $keeptag = $tag ]];
				then 
					found=true;
					break;
			fi;
		done;
		if [ "$found" = false ]; then
  		curl -s -k -u $userName:$password -X 'DELETE' "https://dockerrepo.tosanltd.com/api/v2.0/projects/docker/repositories/$line/artifacts/$tag/tags/$tag" -H 'accept: application/json'
			echo "Deleting ${line}:${tag}"
		fi
		
	done
done <<< "$repositories";

