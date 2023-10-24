#This is code used to predict used car prices using linear regression
#the data set that is used for this is pulled from kaggle: https://www.kaggle.com/code/mohaiminul101/car-price-prediction
#create model
create or replace model bqml_tutorial.used_car_model
options
(model_type ='linear_reg',
input_label_cols=['Selling_Price']
) as
select * from `bqml_tutorial.used_car_data` where Selling_Price is not null;

#evaluate model
select * from 
ml.evaluate(MODEL bqml_tutorial.used_car_model,
(select * from bqml_tutorial.used_car_data where Selling_Price is not null)
);

#predict outcomes

select * from 
ml.predict(MODEL bqml_tutorial.used_car_model,
(select * from bqml_tutorial.used_car_data where Selling_Price is not null));

#explain prediction results

select * 
from 
ml.explain_predict(
  MODEL bqml_tutorial.used_car_model,
  (select * from bqml_tutorial.used_car_data where Selling_Price is not null),
  struct(3 as top_k_features)
);

#globally explain your model

CREATE OR REPLACE MODEL `bqml_tutorial.used_car_model`
OPTIONS
  (model_type='linear_reg',
  input_label_cols=['Selling_Price'],
  enable_global_explain=TRUE) AS
SELECT
  *
FROM
  `bqml_tutorial.used_car_data`
WHERE
  Selling_Price IS NOT NULL;

#access global explanations

SELECT
  *
FROM
  ML.GLOBAL_EXPLAIN(MODEL `bqml_tutorial.used_car_model`);

