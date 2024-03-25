# message
# file name, version, description, usage, design tips
# params and vars
$datetime = (Get-Date -Format 'yyyy-MMM-dd, HH:mm:ss')
$msgbody = 'Configure HTTPS on website'
$commitmessage = "$msgbody at $datetime"
$addtorepository = '.' #'deploy/azure-pipelines.yml'
#command body
git add $addtorepository
git commit -m $commitmessage
git push
# post operation, output handling, etc.