server:
	cd playground && bundle exec restart -d ../. -i \.bundle$$ -i \.git$$ thin start -p 8080
console:
	RACK_ENV=development bundle exec pry -r ./playground/app/config/boot
