server:
	cd playground && bundle exec restart -d ../. -i \.bundle$$ -i \.git$$ thin start -p 8080
