#Power Model generation for ARM.
#Kris Nikov 2016


#How to configure sparse checkout so you dont end up pulling the whole repo if you just want to make changes to ARMPM_buildmodel or ARMPM_datacollect

#1) Initialise ARMPM repo dir
git init ARMPM
cd ARMPM

#2) Then add remotes (or just what you need) 
git remote add origin git@github.com:kranik/ARMPM.git

#3) Configure sparse checkout
git config core.sparsecheckout true
echo "ARMPM_buildmodel/*" >> .git/info/sparse-checkout or echo "ARMPM_datacollect/*" >> .git/info/sparse-checkout
echo ".gitignore" >> .git/info/sparse-checkout && echo "LICENSE" >> .git/info/sparse-checkout && echo "README" >> .git/info/sparse-checkout

#4) Shallow clone 
git pull --depth=1 origin master

Note you can push to origin with this and you avoid getting unnecessary data when pulling. However initial clone will contain the whole repo though checkout is only for the folder specified.