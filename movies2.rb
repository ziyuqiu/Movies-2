class MovieData
	# the constructor of the MovieData class accepts a single 
	# parameter, the file name of the main data file. It reads 
	# the file content in.
	def initialize(fileName)
		@moviehash = Hash.new
		@userhash = Hash.new
		f = open(fileName)
			f.each_line do |line|
				splitted = line.split.map{|e| e.to_i}
				movie_id = splitted[1]
				user_id = splitted[0]
				rating = splitted[2]
				if @moviehash[movie_id].nil?
					@moviehash[movie_id] = Hash.new
				end
				@moviehash[movie_id][user_id] = rating
				if @userhash[user_id].nil?
					@userhash[user_id] = Hash.new
				end
				@userhash[user_id][movie_id] = rating
	  		end	  		
		f.close
	end

	#returns an integer from 1 to 5 to indicate the popularity 
	#of a certain movie.
	def popularity(id)
		#traverse the hash, find every entry of this movie
		if !@moviehash[id].nil?
			popularity = (@moviehash[id].inject(0.0){|sum,el| sum+el[1]} / @moviehash[id].size ).round(2)
		end
	end

	#this will generate a list of all movie_id’s ordered by 
	#decreasing popularity
	def popularity_list
		#popularity(mov_id) gets the popularity of this movie_id
		#moviehash.map gets the popularity of each movie in the moviehash
		#.sort_by sort it by pop(popularity) descendingly
		@popularityhash = @moviehash.map{|mov_id,_| [mov_id,popularity(mov_id)]}.sort_by{|k,pop| -pop}
	end

	#generates a number between 0 and 1 indicating the 
	#similarity in movie preferences between user1 and user2. 
	#0 is no similarity.
	def similarity(user1, user2)
		all_movie = @userhash[user1].map{|e| e[0]} | @userhash[user2].map{|e| e[0]}
		shared_movie = @userhash[user1].map{|e| e[0]} & @userhash[user2].map{|e| e[0]}
		scoretotal = 0
		shared_movie.each do |movie|
			scoretotal += (@moviehash[movie][user1] - @moviehash[movie][user2]).abs
		end
		numdiff = all_movie.length-shared_movie.length
		similarity = (1-(scoretotal+numdiff*4.0)/all_movie.length/5.0).round(2)
	end

	#this return a list of users whose tastes are most similar 
	#to the tastes of user u
	def most_similar(u)	
		@simhash = @userhash.reject{|x| x==u}.map{|user,val| [user,similarity(u,user)]}.sort_by{|k,v| -v}.first 10
	end
end

class Ratings
	def predict(user, movie, userhash1, moviehash1, simlst, popularity)
		#Based on this user's rating history, determine whether this user grades harshly
		pastscore = userhash1[user].values.inject{ |sum, el| sum+el}.to_f / userhash1[user].size
		#Based on the scores given by most similar users, predict a score
		sum = 0.0
		count = 0 
		simlst.each do |s| 
			sc = userhash1[s[0]][movie]  
			if !sc.nil?
				sum +=sc
				count +=1
			end
		end
		predictscore = pastscore.round(2)
		if count != 0
			simscore = (sum/count).round(2)
			predictscore = (pastscore*0.6+simscore*0.4).round(2)			
		elsif !popularity.nil?
				predictscore = (pastscore*0.6+popularity*0.4).round(2)
		end
		predictscore = (predictscore*0.98+0.02).round
	end
end

class Validator
	def validate(base,test)
		@offlst = [0]*9
		base.each do |user|		
			base[user[0]].each do |movie|
				offval = base[user[0]][movie[0]]-test[user[0]][movie[0]]
				@offlst[offval+4] += 1
			end
		end
		print "#{@offlst}\n"
		total = @offlst[0]+@offlst[1]+@offlst[2]+@offlst[3]+@offlst[4]
		mean = (-4..4).inject{|sum,i| sum+@offlst[i+4]*i}/total.round(5)
		stdv = ((-4..4).inject{|sum,i| sum+(i-mean)**2*@offlst[i+4]}/(total-1)).round(5)
		puts "Mean: #{mean}, Stdv:#{stdv}"
	end
end

class Control 
	def initialize(file1, file2)
		@moviedata1 = MovieData.new(file1)
		@moviedata2 = MovieData.new(file2)
		@userhash1 = @moviedata1.instance_variable_get(:@userhash)
		@userhash2 = @moviedata2.instance_variable_get(:@userhash)
		@moviehash1 = @moviedata1.instance_variable_get(:@moviehash)
		@moviehash2 = @moviedata2.instance_variable_get(:@moviehash)
	end

	def run
		puts "Predicting...Please wait."
		pre = Ratings.new
		val = Validator.new
		@predicthash = Hash.new
		@userhash2.each do |usr|
			@predicthash[usr[0]] = Hash.new
			simlst = @moviedata1.most_similar(usr[0])
			@userhash2[usr[0]].each do |mv|
				ppl = @moviedata1.popularity(mv[0])
				predict_result = predict_result = pre.predict(usr[0], mv[0],@userhash1, @moviehash1, simlst,ppl)
				@predicthash[usr[0]][mv[0]] = predict_result
			end
		end
		puts "Valuating...Please wait."
		val.validate(@predicthash,@userhash2)
	end
end

go = Control.new("./ml-100k/u1.base","./ml-100k/u1.test")
go.run