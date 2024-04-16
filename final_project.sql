DROP VIEW churned;
CREATE VIEW churned AS  (
    SELECT 
        cus.CUSTOMERID,
        case WHEN trunc(months_between(sysdate,BIRTHDATE)/12) > 60 THEN '61 +'
             WHEN trunc(months_between(sysdate,BIRTHDATE)/12) > 45 THEN '46 - 60'
             WHEN trunc(months_between(sysdate,BIRTHDATE)/12) > 30 THEN '31 - 45'
             ELSE '18 - 30' END AS age_group,
        MARTIALSTATUS,
        CASE WHEN INCOME >= 2000  THEN '2k +'
             WHEN INCOME >= 1000  THEN '1k - 2k'
             ELSE 'less than 1k' END AS income_category,
        TOTALRELATIONSHIPCOUNT,
        TOTALTRANSACTIONCOUNT,
        CASE WHEN CHURN = 'Yes' THEN 1 ELSE 0 END AS is_churned,
        CASE WHEN trunc(months_between(sysdate,CUSTOMERSINCE)/12) > 65 THEN 1 ELSE 0 END AS is_senior,
        2023 - EXTRACT(YEAR FROM CUSTOMERSINCE) AS tenure
    FROM bank_customers cus
    JOIN bank_churners bc ON cus.CUSTOMERID = bc.CUSTOMERID
        );

-- overall statistics
select SUM(is_churned) Churned_Customers_Count ,
       count(case when is_churned = 0 then CUST OMERID end) Non_Churned_Customers_Count,
       round(SUM(is_churned) / COUNT(*) * 100,2) || '%' AS churn_rate,
       round((count(case when is_churned = 0 then CUSTOMERID end)-count(case when TENURE = 0 then CUSTOMERID end))/count(case when TENURE > 0 then CUSTOMERID end)*100,2) || '%' AS retention_rate,
       round(COUNT(*) / SUM(is_churned)) AS retention_ratio
from churned
group by 1, 2;

--churn_rate by age group and income_category
SELECT 
    age_group,  
    income_category,
    ROUND(SUM(is_churned) / (SELECT COUNT(*) FROM bank_churners)*100, 1) || '%' AS churn_rate_percent,
    ROUND(AVG(TOTALRELATIONSHIPCOUNT)) as avg_total_product_count,
    MIN(TOTALTRANSACTIONCOUNT) as minTRANSACTIONCOUNT12MONTH,
    COUNT(CUSTOMERID) as client_count,
    count(case when is_churned = 0 then CUSTOMERID end) as final_client_count
FROM churned
GROUP BY age_group, 
         income_category
ORDER BY 1, 3 DESC;

--High-Value Churning Customers - how many customers have the highest transaction counts but churned
select case when TOTALTRANSACTIONCOUNT > 500 then '500+'
            when TOTALTRANSACTIONCOUNT > 200 then '201-500'
            else '200 -' end as transaction_category,
    TOTALRELATIONSHIPCOUNT, count(CUSTOMERID) churned_customer_count,
    SUM(count(CUSTOMERID)) OVER(PARTITION BY case when TOTALTRANSACTIONCOUNT > 500 then '500+'
                                                  when TOTALTRANSACTIONCOUNT > 200 then '201-500'
                                                  else '200 -' end) AS total_churned_customer_count
from churned 
where IS_CHURNED = 1
group by TOTALRELATIONSHIPCOUNT, 
case when TOTALTRANSACTIONCOUNT > 500 then '500+'
            when TOTALTRANSACTIONCOUNT > 200 then '201-500'
            else '200 -' end
order by 1 desc, 2 desc;

--how many customers have the highest transaction counts but haven’t signed for a new product this year
select case when TOTALTRANSACTIONCOUNT > 500 then '500+'
            when TOTALTRANSACTIONCOUNT > 200 then '201-500'
            else '200 -' end as transaction_category,
    TOTALRELATIONSHIPCOUNT, count(CUSTOMERID) churned_customer_count,
    SUM(count(CUSTOMERID)) OVER(PARTITION BY case when TOTALTRANSACTIONCOUNT > 500 then '500+'
                                                  when TOTALTRANSACTIONCOUNT > 200 then '201-500'
                                                  else '200 -' end) AS total_non_churned_customer_count
from BANK_CHURNERS 
where CHURN = 'No' and CONTACTSCOUNT12MONTH = 0 and TOTALRELATIONSHIPCOUNT != 7
group by TOTALRELATIONSHIPCOUNT, 
case when TOTALTRANSACTIONCOUNT > 500 then '500+'
            when TOTALTRANSACTIONCOUNT > 200 then '201-500'
            else '200 -' end
order by 1 desc, 2 desc;

--bu il ərzində qeydiyyatdan keçənlərin neçəsi və hansı ayda churn edib
select month, count(CUSTOMERID) churned_customer_count, round(avg(TOTALRELATIONSHIPCOUNT), 0) average_account_count
from (select CUSTOMERID, TOTALRELATIONSHIPCOUNT, 2023 - EXTRACT(YEAR FROM CUSTOMERSINCE) AS tenure, 
             to_char(to_date(CUSTOMERSINCE, 'DD-MM-YYYY'), 'mm') month, churn
      from BANK_CHURNERS)
where tenure = 0 and churn = 'Yes'
group by month
order by 2 desc;


