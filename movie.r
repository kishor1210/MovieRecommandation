
#set working directory
setwd("~/Documents/dataScience/myDSproject/movieRecommandation/ml-20m")

#load datasets
#links <- read.csv("links.csv")
movies<- read.csv("movies.csv", stringsAsFactors = FALSE)
ratings <- read.csv("ratings.csv")
#tags <- read.csv("tags.csv")

#Data Pre-processing
genres <- as.data.frame(movies$genres, stringsAsFactors = FALSE)
library(data.table)

genres2 <- as.data.frame(tstrsplit(genres[,1], '[|]',
                                   type.convert = TRUE),
                         stringsAsFactors = FALSE)
colnames(genres2) <- c(1:10)
str(genres2)

#lets find total genres
total_genre <- setNames(data.frame(NA), "genre")
for(i in 1:ncol(genres2)){
  total_genre <- rbind(total_genre,setNames(data.frame(unique(genres2[,i])), "genre")) 
}
genre_list  <- unique(total_genre)[-1,]

#empty matrix
genre_matrix <- matrix(0,27279,length(genre_list))
genre_matrix[1,]<- genre_list #set first row to genre list
colnames(genre_matrix) <- genre_list

#iterate through matrix
for(i in 1:nrow(genres2)){
  for(c in 1:ncol(genres2)){
    genmat_col <- which(genre_matrix[1,]==genres2[i,c])
    genre_matrix[i+1,genmat_col] <- 1
  }
}

#convert into data frame
genre_matrix <- as.data.frame(genre_matrix[-1,], stringsAsFactors = FALSE)
#convert char into integer
for (i in 1:ncol(genre_matrix)){
  genre_matrix[,i] <-as.integer(genre_matrix[,i]) 
}
#create a searchable csv file 
#Create a matrix to search for a movie by genre:
years <- as.data.frame(movies$title, stringsAsFactors=FALSE)
library(data.table)
substrRight <- function(x, n){
  substr(x, nchar(x)-n+1, nchar(x))
}
years <- as.data.frame(substr(substrRight(substrRight(years$`movies$title`, 6),5),1,4))

search_matrix <- cbind(movies[,1], substr(movies[,2],1,nchar(movies[,2])-6), years, genre_matrix)
colnames(search_matrix) <- c("movieId", "title", "year", genre_list)

write.csv(search_matrix, "search.csv")
search_matrix <- read.csv("search.csv", stringsAsFactors=FALSE)

#Example of search an Action movie produced in 1995.
subset(search_matrix, Action= 1& year ==1995)$title


#create a user profile
binrating <- ratings[1:100000,]

#ratings are converted into likes and dislikes 4,5->1 otherwise ->-1

for (i in 1:nrow(binrating)) {
  binrating[i,3]<- ifelse(binrating[i,3]>3,1,-1)
}

#convert binary matrix to correct format:
binrating2 <- dcast(binrating,movieId~userId, value.var= "rating", na.rm=FALSE)
for(i in 1:ncol(binrating2)){
  binrating2[which(is.na(binrating2[,i])==TRUE),i]<-0
}
binrating2 <- binrating2[,-1] #remove movieId


#Remove rows that are not rated from movies dataset
movieIds <- length(unique(movies$movieId)) #27278
ratingmovieIds <- length(unique(ratings$movieId)) #26744
movies2 <- movies[-which((movies$movieId %in% ratings$movieId) == FALSE),]
rownames(movies2) <- NULL


#Remove rows that are not rated from genre_matrix2
genre_matrix1 <- genre_matrix[-which((movies$movieId %in% ratings$movieId) == FALSE),]
rownames(genre_matrix1) <- NULL


#calculate the dot product of the genre matrix and 
#the ratings matrix and obtain the user profiles

#Calculate dot product for User Profiles
result = matrix(0,20,703) # here, 668=no of users/raters, 18=no of genres
for (c in 1:ncol(binrating2)){
  for (i in 1:ncol(genre_matrix1)){
    result[i,c] <- sum((genre_matrix1[,i]) * (binrating2[,c])) #ratings per genre
  }
}

#convert to binary scale
for(c in 1:ncol(result)){
  for(i in 1:nrow(result)){
    result[i,c]<- ifelse(result[i,c]<0,0,1)
  }
}

#Assume that user like similar items, and retrieve movies
#that are closest in similarity to a user's profile, which
#represents a user's preference for an item's feature.
#use Jaccard Distance to measure the similaritybetween user profiles

#The User-Based collaborative Filtering Approach

library(reshape2)
#Create ratings matrix. Rows=userId, Columns = movieId
rat <- ratings[1:100000,]
ratingmat <- dcast(rat, userId ~movieId, value.var = "rating", na.rm=FALSE)
ratingmat <- as.matrix(ratingmat[,-1]) #remove userIds


#Method: UBCF
#Similarity Calculation Method: Cosine Similarity
#Nearest Neighbors : 30

library(recommenderlab)
#convert rating matrix into a recommenderlab sparse matrix
ratingmat <- as(ratingmat, "realRatingMatrix")


# Determine how similar the first four users are with each other
# create similarity matrix
similarity_users <- similarity(ratingmat[1:4, ], 
                               method = "cosine", 
                               which = "users")
as.matrix(similarity_users)
image(as.matrix(similarity_users), main = "User similarity")


# compute similarity between
# the first four movies
similarity_items <- similarity(ratingmat[, 1:4], method =
                                 "cosine", which = "items")
as.matrix(similarity_items)
image(as.matrix(similarity_items), main = "Item similarity")

# Exploring values of ratings:
vector_ratings <- as.vector(ratingmat@data)
unique(vector_ratings) # what are unique values of ratings

table_ratings <- table(vector_ratings) # what is the count of each rating value
table_ratings

# Visualize the rating:
vector_ratings <- vector_ratings[vector_ratings != 0] # rating == 0 are NA values
vector_ratings <- factor(vector_ratings)

library(ggplot2)
qplot(vector_ratings) + 
  ggtitle("Distribution of the ratings")

# Exploring viewings of movies:
views_per_movie <- colCounts(ratingmat) # count views for each movie

table_views <- data.frame(movie = names(views_per_movie),
                          views = views_per_movie) # create dataframe of views
table_views <- table_views[order(table_views$views, 
                                 decreasing = TRUE), ] # sort by number of views

ggplot(table_views[1:6, ], aes(x = movie, y = views)) +
  geom_bar(stat="identity") + 
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) + 
  scale_x_discrete(labels=subset(movies2, movies2$movieId == table_views$movie)$title) +
  ggtitle("Number of views of the top movies")


#Visualizing the matrix:
image(ratingmat, main = "Heatmap of the rating matrix") # hard to read-too many dimensions
image(ratingmat[1:10, 1:15], main = "Heatmap of the first rows and columns")
image(ratingmat[rowCounts(ratingmat) > quantile(rowCounts(ratingmat), 0.99),
                colCounts(ratingmat) > quantile(colCounts(ratingmat), 0.99)], 
      main = "Heatmap of the top users and movies")


#Normalize the data
ratingmat_norm <- normalize(ratingmat)
image(ratingmat_norm[rowCounts(ratingmat_norm) > quantile(rowCounts(ratingmat_norm), 0.99),
                     colCounts(ratingmat_norm) > quantile(colCounts(ratingmat_norm), 0.99)], 
      main = "Heatmap of the top users and movies")

#Create UBFC Recommender Model. UBCF stands for User-Based Collaborative Filtering
recommender_model <- Recommender(ratingmat_norm, 
                                 method = "UBCF", 
                                 param=list(method="Cosine",nn=30))

model_details <- getModel(recommender_model)
model_details$data

recom <- predict(recommender_model, 
                 ratingmat[1], 
                 n=10) #Obtain top 10 recommendations for 1st user in dataset

recom

#recc_matrix <- sapply(recom@ite
#                      function(x){ colnames(ratingmat)[x] })
#dim(recc_matrix)

recom_list <- as(recom, 
                 "list") #convert recommenderlab object to readable list

#Obtain recommendations
recom_result <- matrix(0,10)
for (i in 1:10){
  recom_result[i] <- as.character(subset(movies, 
                                         movies$movieId == as.integer(recom_list[[1]][i]))$title)
}


# Evaluation:
evaluation_scheme <- evaluationScheme(ratingmat, 
                                      method="cross-validation", 
                                      k=5, given=3, 
                                      goodRating=5) #k=5 meaning a 5-fold cross validation. given=3 meaning a Given-3 protocol
evaluation_results <- evaluate(evaluation_scheme, 
                               method="UBCF", 
                               n=c(1,3,5,10,15,20))
eval_results <- getConfusionMatrix(evaluation_results)[[1]]


