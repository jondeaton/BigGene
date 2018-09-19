
# install maven
sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven

# isntall git and clone adam
sudo yum install -y git tmux htop s3-dist-cp
git clone https://github.com/jondeaton/adam.git
cd adam

# chagen the java versions
echo 1 | sudo /usr/sbin/alternatives --config java
echo 1 | sudo /usr/sbin/alternatives --config javac

git checkout feature/SparkSQL
mvn -DskipTests=true clean package

echo "set-option -g prefix C-x" >> ~/.tmux.conf

sudo yum install -y hadoop-yarn-nodemanager
initctl list | grep yarn
sudo stop hadoop-yarn-nodemanager
sudo start hadoop-yarn-nodemanager