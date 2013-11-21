#!/bin/bash

# rfe.sh: 更改文件扩展名.
#         rfe old_extension new_extension
# 例如:
# T为了把当前目录下所有的*.gif文件改成*.jpg,如下执行：
#          rfe gif jpg
 
E_BADARGS=65

case $# in
 0|1)             # 在这里，竖线(|)意味着"或"。
 echo "Usage: `basename $0` old_file_suffix new_file_suffix"
 exit $E_BADARGS  # 如果是0或1，就退出脚本
;;
esac

for filename in *.$1
# 把文件名以第一个参数为后缀的文件全部列举出来
 do
   mv $filename ${filename%$1}$2
   #  剥去文件名中匹配第一个参数的部分,
   #+ 然后加上第二个参数.
done

exit 0

