/*
Hotel Reservation Data Exploration

Skill used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/


  SELECT TOP 10 *
  FROM res_card
  WHERE property_id IS NOT NULL
  ORDER BY res_id;


-- Selecting Data that we are going to start with

  SELECT res_id, res_status_id, check_in_date, check_out_date, adults, children, room_type_booked_id, rate_type_id, created_timestamp, cancelled_timestamp
  FROM res_card
  WHERE property_id IS NOT NULL
  ORDER BY res_id;

  -- Looking at Check in date vs Created timestamp
  -- Shows lead time (number of days in advance a booking is made)


  SELECT 
  	res_id, 
  	res_status_id, 
	created_timestamp,
  	check_in_date, 
	created_timestamp, 
  	DATEDIFF(day, created_timestamp, check_in_date) AS DateDiff
  FROM res_card
  --WHERE property_id IS NOT NULL
  ORDER BY res_id;


-- Looking at reservations cancelled the same day of arrival

SELECT 
  res_id, 
  res_status_id, 
  check_in_date, 
  created_timestamp, 
  DATEDIFF(day, cancelled_timestamp, check_in_date) AS leadtime
FROM res_card
WHERE DATEDIFF(day, cancelled_timestamp, check_in_date) = 0
ORDER BY res_id;

-- Showing average number of guests per room type for arrivals during the first week of 2022

  SELECT check_in_date, AVG(adults + children) AS 'avg guests', room_type_booked_id
  FROM res_card
  --WHERE check_in_date BETWEEN '2022-01-01' AND '2022-01-07'
  GROUP BY check_in_date, room_type_booked_id
  ORDER BY 1

-- Showing percentage of children arriving on December 31 per room type

  SELECT 
	check_in_date, 
	SUM(children) as total_children, 
	SUM(adults + children) as total_guests, 
	ROUND(CAST(SUM(children) AS FLOAT) / NULLIF(SUM(adults + children), 0) * 100, 2) AS 'children_percent', 
	room_type_booked_id
  FROM res_card
  WHERE check_in_date = '2022-12-31'
  GROUP BY check_in_date, room_type_booked_id
  ORDER BY 1


  -- Joining res_status table to control for in-house guests
  -- Showing in-house guests staying on or after Jan 1, 2023

  SELECT r.res_id, r.res_status_id, r.guest_name, check_in_date
  FROM res_card r
  INNER JOIN res_status rs
		ON r.res_status_id = rs.id
  WHERE rs.description = 'In House' AND check_in_date >= '2023-01-01'

  -- Using CTE to perform to get global average lenght of stay
  -- Showing non refundable reservations with staying longer than the averge amount of nights

 WITH average_los AS (
	SELECT AVG(DATEDIFF(day, check_in_date, check_out_date)) AS avg_los
	FROM res_card
)
SELECT r.res_id, r.person_profile_id, r.check_in_date, r.check_out_date, a.avg_los 
FROM average_los a, res_card r
INNER JOIN rate_types rt
	ON r.rate_type_id = rt.rate_type_id
WHERE rt.rate_type_name = 'non refundable' AND DATEDIFF(day, check_in_date, check_out_date) > avg_los


-- Creating VIEW to store data for later visualization
-- Performing calculation on Partition By to show reservation's running stay total

CREATE VIEW res_running_total AS

SELECT 
	r.res_id, 
	r.person_profile_id, 
	rrg.stay_date, 
	rrg.rate, 
	SUM(rate) OVER (PARTITION BY rrg.res_card_ref_id ORDER BY stay_date) AS stay_running_total
FROM res_card r
INNER JOIN res_rate_grid rrg
	ON r.reference_id = rrg.res_card_ref_id
LEFT JOIN rate_types rt
	ON r.rate_type_id = rt.rate_type_id
WHERE rt.rate_type_name = 'non refundable'


-- Using TEMP TABLE along with CASE for conditional statements
-- Showing cancelled reservations and respective penalties

DROP TABLE IF EXISTS #cancel_penalty;

CREATE TABLE #cancel_penalty (
    res_id INT,
    cancelled_timestamp DATETIME,
    total_guests INT,
    cancel_penalty DECIMAL(10,2)
);

INSERT INTO #cancel_penalty
SELECT 
    r.res_id, 
    r.cancelled_timestamp,
    r.adults + r.children AS total_guests,
    CASE
        WHEN r.adults + r.children = 1 THEN 0
        WHEN r.adults + r.children = 2 THEN 25
        WHEN r.adults + r.children = 3 THEN 50
        ELSE 100
    END AS cancel_penalty
FROM res_card r
LEFT JOIN rate_type rt
    ON r.rate_type_id = rt.rate_type_id
WHERE rt.rate_type_name = 'refundable';




