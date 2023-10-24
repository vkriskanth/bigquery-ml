#This is code used to predict used car prices using linear regression
create or replace model bqml_tutorial.used_car_model
options
(model_type ='linear_reg',
input_label_cols=['Selling_Price']
) as
select * from `bqml_tutorial.used_car_data` where Selling_Price is not null 
