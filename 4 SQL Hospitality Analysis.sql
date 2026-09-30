CREATE DATABASE hospitality_analytics;
USE hospitality_analytics;
SHOW TABLES;

DESCRIBE dim_date;
DESCRIBE dim_hotels;
DESCRIBE dim_rooms;
DESCRIBE fact_aggregated_bookings;
DESCRIBE fact_bookings;

SELECT COUNT(*) FROM fact_bookings;
SELECT COUNT(*) FROM fact_aggregated_bookings;
SELECT COUNT(*) FROM dim_date;
SELECT COUNT(*) FROM dim_hotels;
SELECT COUNT(*) FROM dim_rooms;

SELECT * FROM dim_date;
SELECT * FROM dim_hotels;
SELECT * FROM dim_rooms;
SELECT * FROM fact_bookings;
SELECT * FROM fact_aggregated_bookings;

SELECT * FROM fact_bookings LIMIT 10;
SELECT * FROM fact_aggregated_bookings LIMIT 10;
SELECT * FROM dim_hotels LIMIT 10;
SELECT * FROM dim_rooms LIMIT 10;
SELECT * FROM dim_date LIMIT 10;

-- NULL valaues
SELECT COUNT(*) AS null_booking_ids
FROM fact_bookings
WHERE booking_id IS NULL;


-- --------------------KPIs----------------------------------
-- KPI 1 —Total Revenue
SELECT SUM(revenue_realized) AS total_revenue
FROM fact_bookings;

-- KPI 2 — Total Bookings
SELECT COUNT(booking_id) AS total_bookings
FROM fact_bookings;

-- KPI 3 — Total Capacity
SELECT SUM(capacity) AS total_capacity
FROM fact_aggregated_bookings;

-- KPI 4 — Total Successful Bookings
SELECT SUM(successful_bookings) AS total_successful_bookings
FROM fact_aggregated_bookings;

-- KPI 5 — Occupancy %
SELECT ROUND(SUM(successful_bookings) * 100.0/ NULLIF(SUM(capacity), 0),2) AS occupancy_percentage
FROM fact_aggregated_bookings;

-- KPI 6 — Average Rating
SELECT ROUND(AVG(NULLIF(ratings_given, 0)), 2) AS average_rating
FROM fact_bookings;

-- KPI 7 — Number of Days
SELECT COUNT(DISTINCT date) AS number_of_days
FROM dim_date;

-- KPI 8 — Total Cancelled Bookings
SELECT COUNT(booking_id) AS total_cancelled_bookings
FROM fact_bookings
WHERE booking_status = 'Cancelled';

-- KPI 9 — Cancellation %
SELECT ROUND(SUM(CASE
                  WHEN booking_status = 'Cancelled' THEN 1
                 ELSE 0
                 END) * 100.0/ COUNT(booking_id),2) AS cancellation_percentage
FROM fact_bookings;

-- KPI 10 — Total Checked Out
SELECT COUNT(booking_id) AS total_checked_out
FROM fact_bookings
WHERE booking_status = 'Checked Out';

-- KPI 11 — Total No-Show Bookings
SELECT COUNT(booking_id) AS total_no_show_bookings
FROM fact_bookings
WHERE booking_status = 'No Show';

-- KPI 12 — No-Show Rate %
SELECT ROUND(SUM(CASE
                    WHEN booking_status = 'No Show' THEN 1
				 ELSE 0
                 END) * 100.0/ COUNT(booking_id),2) AS no_show_rate_percentage
FROM fact_bookings;

-- KPI 13 — Booking % by Platform
SELECT booking_platform,COUNT(booking_id) AS total_bookings,
    ROUND(COUNT(booking_id) * 100.0/ SUM(COUNT(booking_id)) OVER (),2) AS booking_percentage
FROM fact_bookings
GROUP BY booking_platform
ORDER BY booking_percentage DESC;

-- KPI 14 — Booking % by Room Class
SELECT dr.room_class,COUNT(fb.booking_id) AS total_bookings,
    ROUND(COUNT(fb.booking_id) * 100.0/ SUM(COUNT(fb.booking_id)) OVER (),2) AS booking_percentage
FROM fact_bookings fb
JOIN dim_rooms dr ON fb.room_category = dr.room_id
GROUP BY dr.room_class
ORDER BY booking_percentage DESC;

-- KPI 15 — ADR
SELECT ROUND(SUM(revenue_realized) * 1.0/ NULLIF(COUNT(booking_id), 0),2) AS ADR
FROM fact_bookings;

-- KPI 16 — Realisation %
SELECT ROUND(SUM(CASE WHEN booking_status = 'Checked Out' THEN 1
                ELSE 0
            END) * 100.0/ COUNT(booking_id),2) AS realisation_percentage
FROM fact_bookings;

-- KPI 17 — RevPAR
SELECT ROUND(SUM(fb.revenue_realized) * 1.0 /NULLIF(232576, 0),2) AS RevPAR
FROM fact_bookings fb;

-- KPI 18 — DBRN
SELECT ROUND(SUM(successful_bookings) * 1.0/ COUNT(DISTINCT check_in_date),2) AS DBRN
FROM fact_aggregated_bookings;

-- KPI 19 — DSRN
SELECT  ROUND(SUM(capacity) * 1.0 / COUNT(DISTINCT check_in_date),2) AS DSRN
FROM fact_aggregated_bookings;

-- KPI 20 — DURN
SELECT ROUND(SUM(successful_bookings) * 1.0/ COUNT(DISTINCT check_in_date),3) AS DURN
FROM fact_aggregated_bookings;

-- KPI 21 — Revenue WoW Change %
WITH weekly_revenue AS (
SELECT dd.`week no` AS week_no,SUM(fb.revenue_realized) AS revenue
    FROM fact_bookings fb
    JOIN dim_date dd ON fb.check_in_date = dd.date
    GROUP BY dd.`week no`),
wow AS (SELECT week_no,revenue,LAG(revenue) OVER (ORDER BY week_no) AS previous_week_revenue
        FROM weekly_revenue)
SELECT week_no AS `Week No`,
    ROUND(revenue, 2) AS `Revenue`,
    ROUND(previous_week_revenue, 2) AS `Previous Week Revenue`,
    ROUND((revenue - previous_week_revenue) * 100.0/ NULLIF(previous_week_revenue, 0),2) AS `Revenue WoW %`
FROM wow
ORDER BY week_no;

-- KPI 22 — Occupancy WoW Change %
WITH weekly_occupancy AS (
    SELECT dd.`week no` AS week_no,
        SUM(fa.successful_bookings) AS successful_bookings,
        SUM(fa.capacity) AS capacity,
        SUM(fa.successful_bookings) * 100.0/ NULLIF(SUM(fa.capacity), 0) AS occupancy
    FROM fact_aggregated_bookings fa
    JOIN dim_date dd ON fa.check_in_date = dd.date
    GROUP BY dd.`week no`),
wow AS (SELECT week_no,occupancy,LAG(occupancy) OVER (ORDER BY week_no) AS previous_occupancy
    FROM weekly_occupancy)
SELECT week_no AS `Week No`,
    ROUND(occupancy, 2) AS `Occupancy %`,
    ROUND(previous_occupancy, 2) AS `Previous Week Occupancy %`,
    ROUND((occupancy - previous_occupancy) * 100.0/ NULLIF(previous_occupancy, 0),2) AS `Occupancy WoW %`
FROM wow
ORDER BY week_no;

-- KPI 23 — ADR WoW Change %
WITH weekly_adr AS (
    SELECT dd.`week no` AS week_no,
        SUM(fb.revenue_realized) * 1.0/ NULLIF(SUM(CASE
                                                     WHEN fb.booking_status = 'Checked Out'
                                                     THEN 1
                                                   ELSE 0
                                                   END), 0) AS ADR
    FROM fact_bookings fb
    JOIN dim_date dd ON fb.check_in_date = dd.date
    GROUP BY dd.`week no`),
wow AS (SELECT week_no,ADR,LAG(ADR) OVER (ORDER BY week_no) AS previous_week_ADR
        FROM weekly_adr)
SELECT week_no AS `Week No`,
	  ROUND(ADR, 2) AS `ADR`,
      ROUND(previous_week_ADR, 2) AS `Previous Week ADR`,
	  ROUND((ADR - previous_week_ADR) * 100.0/ NULLIF(previous_week_ADR, 0),2) AS `ADR WoW Change %`
FROM wow
ORDER BY week_no;

-- KPI 24 — RevPAR WoW Change %
WITH weekly_revpar AS (
    SELECT dd.`week no` AS week_no,
        SUM(fb.revenue_realized) AS revenue,
        SUM(fa.capacity) AS capacity,
        SUM(fb.revenue_realized) * 1.0/ NULLIF(SUM(fa.capacity), 0) AS revpar
    FROM fact_aggregated_bookings fa
    JOIN dim_date dd ON fa.check_in_date = dd.date
    JOIN (SELECT check_in_date,property_id,room_category,SUM(revenue_realized) AS revenue_realized
          FROM fact_bookings
          GROUP BY check_in_date,property_id,room_category) fb ON fa.check_in_date = fb.check_in_date
          AND fa.property_id = fb.property_id 
          AND fa.room_category = fb.room_category
          GROUP BY dd.`week no`),
wow AS (SELECT week_no,revpar,LAG(revpar) OVER (ORDER BY week_no) AS previous_week_revpar
    FROM weekly_revpar)
SELECT week_no AS `Week No`,
   ROUND(revpar, 2) AS `RevPAR`,
   ROUND(previous_week_revpar, 2) AS `Previous Week RevPAR`,
   ROUND((revpar - previous_week_revpar) * 100.0/ NULLIF(previous_week_revpar, 0),2) AS `RevPAR WoW Change %`
FROM wow
ORDER BY week_no;

-- KPI 25 — DSRN WoW Change %
WITH weekly_dsrn AS (
    SELECT dd.`week no` AS week_no,SUM(fa.capacity) * 1.0/ COUNT(DISTINCT fa.check_in_date) AS dsrn
    FROM fact_aggregated_bookings fa
    JOIN dim_date dd ON fa.check_in_date = dd.date
    GROUP BY dd.`week no`),
wow AS (SELECT week_no,dsrn,LAG(dsrn) OVER (ORDER BY week_no) AS previous_week_dsrn
        FROM weekly_dsrn)
SELECT week_no AS `Week No`,
   ROUND(dsrn, 2) AS `DSRN`,
   ROUND(previous_week_dsrn, 2) AS `Previous Week DSRN`,
   ROUND((dsrn - previous_week_dsrn) * 100.0/ NULLIF(previous_week_dsrn, 0),2) AS `DSRN WoW Change %`
FROM wow
ORDER BY week_no;

--  --------------CHARTS-------------------------------

-- 1.Which hotels generate the most revenue?
SELECT dh.property_id,dh.property_name,dh.city,dh.category,SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_hotels dh ON fb.property_id = dh.property_id
GROUP BY dh.property_id,dh.property_name,dh.city,dh.category
ORDER BY revenue DESC;

-- 2. Revenue by City
SELECT dh.city,SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_hotels dh ON fb.property_id = dh.property_id
GROUP BY dh.city
ORDER BY revenue DESC;

-- 3. Revenue by Hotel Category
SELECT dh.category,SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
JOIN dim_hotels dh ON fb.property_id = dh.property_id
GROUP BY dh.category
ORDER BY revenue DESC;

-- 4. Monthly Revenue
SELECT DATE_FORMAT(STR_TO_DATE(fb.check_in_date, '%Y-%m-%d'),'%Y-%m') AS month,
       SUM(fb.revenue_realized) AS revenue
FROM fact_bookings fb
GROUP BY month
ORDER BY month;

-- 5. Revenue by Booking Platform
SELECT booking_platform,SUM(revenue_realized) AS revenue,COUNT(booking_id) AS bookings
FROM fact_bookings
GROUP BY booking_platform
ORDER BY revenue DESC;

-- 6. Occupancy by Hotel
SELECT dh.property_id,dh.property_name,dh.city,
	SUM(fa.successful_bookings) AS successful_bookings,
    SUM(fa.capacity) AS capacity,
    ROUND(SUM(fa.successful_bookings) * 100.0/ NULLIF(SUM(fa.capacity), 0),2) AS occupancy_percentage
FROM fact_aggregated_bookings fa
JOIN dim_hotels dh ON fa.property_id = dh.property_id
GROUP BY dh.property_id,dh.property_name,dh.city
ORDER BY occupancy_percentage DESC;

-- 7. Revenue by Room Class
SELECT dr.room_class,
  SUM(fb.revenue_realized) AS revenue,COUNT(fb.booking_id) AS bookings
FROM fact_bookings fb
JOIN dim_rooms dr ON fb.room_category = dr.room_id
GROUP BY dr.room_class
ORDER BY revenue DESC;

-- 8.Weekend vs Weekday Revenue
SELECT dd.day_type AS `Day Type`,
  SUM(fb.revenue_realized) AS `Revenue`,
  COUNT(fb.booking_id) AS `Bookings`
FROM fact_bookings fb
JOIN dim_date dd ON fb.check_in_date = dd.date
GROUP BY dd.day_type;

-- 9. Weekend vs Weekday Occupancy
SELECT dd.day_type AS `Day Type`,
    SUM(fa.successful_bookings) AS `Successful Bookings`,
    SUM(fa.capacity) AS `Capacity`,
    ROUND(SUM(fa.successful_bookings) * 100.0/ NULLIF(SUM(fa.capacity), 0),2) AS `Occupancy %`
FROM fact_aggregated_bookings fa
JOIN dim_date dd ON fa.check_in_date = dd.date
GROUP BY dd.day_type;

-- 10. Complete Hotel Performance Report
WITH booking_summary AS (SELECT property_id,SUM(revenue_realized) AS revenue,COUNT(DISTINCT booking_id) AS total_bookings,
										SUM(CASE
											WHEN booking_status = 'Cancelled'
											   THEN 1
											ELSE 0
                                               END) AS cancelled_bookings,ROUND(SUM(CASE
																				    WHEN booking_status = 'Cancelled'
                                                                                      THEN 1
                                                                                    ELSE 0
                                                                                    END) * 100.0/ NULLIF(COUNT(booking_id), 0),2) AS cancellation_percentage
                        FROM fact_bookings
                        GROUP BY property_id),
                        
aggregated_summary AS (SELECT property_id,SUM(successful_bookings) AS successful_bookings,SUM(capacity) AS capacity
    FROM fact_aggregated_bookings
    GROUP BY property_id)
SELECT dh.property_id,dh.property_name,dh.city,dh.category,bs.revenue,bs.total_bookings,ag.successful_bookings,ag.capacity,
    ROUND(ag.successful_bookings * 100.0/ NULLIF(ag.capacity, 0),2) AS occupancy_percentage,ROUND(bs.revenue * 1.0/ NULLIF(ag.successful_bookings, 0),2) AS ADR,
    ROUND(bs.revenue * 1.0/ NULLIF(ag.capacity, 0),2) AS RevPAR,bs.cancelled_bookings,bs.cancellation_percentage
FROM dim_hotels dh
JOIN booking_summary bs ON dh.property_id = bs.property_id
JOIN aggregated_summary ag ON dh.property_id = ag.property_id
ORDER BY bs.revenue DESC;