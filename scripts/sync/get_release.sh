#!/bin/bash --
# Copyright [2009-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

release=$(get_release.sh)
release=${release/_[0-9]*/}
rem=$(( $release % 2 ))
if [ "$rem" -eq 0 ]
then
  echo "mysql-staging-2"
else
  echo "mysql-staging-1"
fi
[ensgen@ebi-cli-001 ~]$ cat bin/get_release.sh
#!/bin/bash --
# Copyright [2009-2019] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

release=$(mysql-pan-1 ensembl_production --column-names=false -e "select distinct(db_release) from db where is_current=1")
echo $release
