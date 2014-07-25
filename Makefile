generate-js: deps
	@find src -name '*.coffee' | xargs coffee -c -o lib

remove-js:
	@rm -fr lib/

deps:
	@test `which coffee` || echo 'You need to have CoffeeScript in your PATH.\nPlease install it using `brew install coffee-script` or `npm install coffee-script`.'

test: generate-js
	@./node_modules/.bin/mocha --compilers coffee:coffee-script/register --reporter spec -r spec/spec_helper.js spec/reverse_competition_ranking_leaderboard_spec.coffee spec/reverse_tie_ranking_leaderboard_spec.coffee spec/competition_ranking_leaderboard_spec.coffee spec/tie_ranking_leaderboard_spec.coffee spec/leaderboard_spec.coffee

publish: generate-js
	@test `which npm` || echo 'You need npm to do npm publish... makes sense?'
	npm publish
	@remove-js

link: generate-js
	@test `which npm` || echo 'You need npm to do npm link... makes sense?'
	npm link
	@remove-js
