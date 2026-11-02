SELECT COUNT(*) FROM listings;
SELECT COUNT(*) FROM availability_per_listing;
SELECT COUNT(*) FROM reviews_by_month;
SELECT * FROM listings;
-- listing count by neighbourhood 
SELECT neighbourhood_cleansed AS neighbourhood,
       COUNT(*) AS listing_count
FROM listings
GROUP BY neighbourhood
ORDER BY listing_count DESC
LIMIT 10;
SELECT * FROM listings;
--neighbourhood median price

SELECT neighbourhood_cleansed AS neighbourhood,
     ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price))::numeric,2) AS median_value,
	 COUNT(price) AS priced_listing
FROM listings
GROUP BY neighbourhood
ORDER BY median_value DESC
LIMIT 10;
-- room type share
WITH ts AS(SELECT room_type, COUNT(*) listing_count
           FROM listings
           GROUP BY room_type)
SELECT room_type,listing_count,
       ROUND(listing_count*100.0/(SELECT COUNT(*) FROM listings),1) AS percentage
FROM ts
ORDER BY listing_count DESC;
-- do superhosts charge more and score higher than non-superhosts?
SELECT host_is_superhost,
       COUNT(*) AS listing_count,
	   ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY price))::numeric,2) AS median_value,
	   ROUND((AVG(review_scores_rating)),2) avg_rating
FROM listings
GROUP BY host_is_superhost;
-- how many listings does each host own & how many hosts own more than 5?
WITH lc AS(SELECT host_id,
          COUNT(*) AS listing_count 
          FROM listings 
          GROUP BY host_id
          HAVING COUNT(*) > 5)
SELECT COUNT(*) host_count,
      SUM(listing_count) AS total_listing,
      ROUND(SUM((listing_count)*100.0/(SELECT COUNT(*) FROM listings)),2) AS percentage
FROM lc;
--CREATE TABLE availability_by_month(
--  month TEXT PRIMARY KEY,
--  available NUMERIC
--);
--which month is the busiest ?
SELECT month, 
      ROUND((available),3) AS availability_share
FROM availability_by_month
ORDER BY availability_share
LIMIT 1;
--Which month is the quietest?
SELECT month, 
      ROUND((available),3) AS availability_share
FROM availability_by_month
ORDER BY availability_share DESC
LIMIT 1;
-- how has review volume changed over time?
SELECT * FROM reviews_by_month
ORDER BY review_count DESC
LIMIT 10;
SELECT LEFT(month, 4) AS yr, 
      SUM(review_count) total_review
FROM reviews_by_month
GROUP BY yr
ORDER BY yr ;
WITH tr AS(SELECT LEFT(month, 4) AS yr, 
          SUM(review_count) total_review
          FROM reviews_by_month
          GROUP BY yr
          )
SELECT yr, total_review
FROM tr 
WHERE yr IN('2020', '2021');

--Which listings have lots of reviews but a low rating?
SELECT id, 
      neighbourhood_cleansed, 
      number_of_reviews,
      review_scores_rating
FROM listings
WHERE number_of_reviews >= (SELECT
      PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY number_of_reviews)
      FROM listings)
AND review_scores_rating <= 4.0
ORDER BY review_scores_rating;
SELECT neighbourhood_cleansed AS neighbourhood,
       COUNT(*) AS flagged_listings
FROM listings
WHERE number_of_reviews >= (SELECT
      PERCENTILE_CONT(.9) WITHIN GROUP(ORDER BY number_of_reviews)
      FROM listings)
AND review_scores_rating <= 4.0
GROUP BY neighbourhood
ORDER BY flagged_listingS DESC;
;
SELECT neighbourhood_cleansed,
      COUNT(*) AS listing_count,
	  
      ROUND(AVG((1-availability_rate)*100),1) AS occupancy_pct
FROM availability_per_listing al
INNER JOIN listings l ON 
al.listing_id = l.id
GROUP BY neighbourhood_cleansed
ORDER BY occupancy_pct;
--Which neighbourhoods have a high price but low occupancy?
WITH nc AS(SELECT neighbourhood_cleansed,
           COUNT(*) AS listing_count,
		   COUNT(price) AS priced_listings,
	       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY price))::numeric,2) AS median_value,
	       ROUND((AVG(1-availability_rate)*100),1) AS occupancy_pct
           FROM availability_per_listing al
           INNER JOIN listings l ON 
           al.listing_id = l.id
           GROUP BY neighbourhood_cleansed
           ORDER BY median_value DESC),
    mv AS(SELECT AVG(median_value) AS avg_med,
	      AVG(occupancy_pct) AS avg_pct
		  FROM nc)
SELECT nc.neighbourhood_cleansed,
       nc.listing_count,
	   nc.priced_listings,
	   nc.median_value,
	   nc.occupancy_pct
FROM nc
CROSS JOIN mv
WHERE nc.median_value > mv.avg_med
  AND nc.occupancy_pct < mv.avg_pct
ORDER BY nc.median_value DESC;
