--link from where we got this code stack: this is sort of original code from the tutorial
-- https://cloud.google.com/blog/topics/developers-practitioners/performing-sentiment-analysis-with-bigquery-ml-using-sparse-features
SELECT
 review,
 label,
FROM 
 `bigquery-public-data.imdb.reviews`
WHERE
 label IN ('Negative', 'Positive');

select count(*) from `bigquery-public-data.imdb.reviews`;

create schema if not exists sparse_features_demo;

create or replace table `sparse_features_demo.processed_reviews` as 
select row_Number() over () as review_number,
review,
regexp_extract_all(lower(review), '[a-z]{2,}') as words,
label,
split
from
(
select distinct review,
label,
split
from `bigquery-public-data.imdb.reviews`
where label in ('Negative','Positive')
);


select * from `sparse_features_demo.processed_reviews`;


create or replace table sparse_features_demo.vocabulary as (
select
word,
word_frequency,
word_index
from
(
  select word,
  word_frequency,
  row_number() over (order by word_frequency desc) -1 as word_index
  from 
(
  select word,count(word) as word_frequency
  from `sparse_features_demo.processed_reviews`,
  unnest(words) as word
  where split="train"
  group by word
)
)
where word_index < 20000
);

select * from sparse_features_demo.vocabulary;

--generate a sparse feature by aggregating word_index and word frequency in each review 

create or replace table `sparse_features_demo.sparse_feature` as (
select
review_number, 
review,
array_agg(struct(word_index,word_frequency)) as feature,
label,
split
from (
select distinct 
review_number,
review,
word,
label,
split from `sparse_features_demo.processed_reviews`,
unnest(words) as word
where word in (select word from `sparse_features_demo.vocabulary`)
) as word_list
left join
`sparse_features_demo.vocabulary` as topk_words
on word_list.word = topk_words.word
group by
review_number,
review,
label,
split
);

select * from `sparse_features_demo.sparse_feature`;

--train a logistic regression classifier using the data with sparse feature
create or replace model sparse_features_demo.logistic_reg_classifier
transform(
  * EXCEPT (
    review_number,
    review
  )
)
options(
  model_type = 'LOGISTIC_REG',
  INPUT_LABEL_COLS=['label']
) as
select 
review_number,
review,
feature,
label
from 
sparse_features_demo.sparse_feature
where split='train';


-- Evaluate the trained logistic regression classifier
SELECT * FROM ML.EVALUATE(MODEL sparse_features_demo.logistic_reg_classifier);

-- Evaluate the trained logistic regression classifier using test data
SELECT * FROM ML.EVALUATE(MODEL sparse_features_demo.logistic_reg_classifier,
 (
   SELECT
     review_number,
     review,
     feature,
     label
   FROM
     sparse_features_demo.sparse_feature
   WHERE
     split = "test"
 )
);


--now comes infereence
WITH
 -- Create a user defined reviews
 user_defined_reviews AS (
   SELECT
     ROW_NUMBER() OVER () AS review_number,
     review,
     REGEXP_EXTRACT_ALL(LOWER(review), '[a-z]{2,}') AS words
   FROM (
     SELECT "What a boring movie" AS review UNION ALL
     SELECT "I don't like this movie" AS review UNION ALL
     SELECT "The best movie ever" AS review
   )
 ),


 -- Create a sparse feature from user defined reviews
 user_defined_sparse_feature AS (
   SELECT
     review_number,
     review,
     ARRAY_AGG(STRUCT(word_index, word_frequency)) AS feature
   FROM (
     SELECT
       DISTINCT review_number,
       review,
       word
     FROM
       user_defined_reviews,
       UNNEST(words) as word
     WHERE
       word IN (SELECT word FROM sparse_features_demo.vocabulary)
   ) AS word_list
   LEFT JOIN
     sparse_features_demo.vocabulary AS topk_words
     ON
       word_list.word = topk_words.word
   GROUP BY
     review_number,
     review
 )


-- Evaluate the trained model using user defined data
SELECT review, predicted_label FROM ML.PREDICT(MODEL sparse_features_demo.logistic_reg_classifier,
 (
   SELECT
     *
   FROM
     user_defined_sparse_feature
 )
);

