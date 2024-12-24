/*
CASE 1. One month after the website's launch (March 19 - April 30), the manager wants to evaluate its initial performance 
by analyzing weekly traffic trends, top traffic sources, and a detailed analysis of those sources.
*/

-- Weekly Traffic Trends
SELECT DATE_TRUNC('Week', created_at)::date AS weekly_date, -- Start of the week
       COUNT(website_session_id) AS total_traffic -- Total number of sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-29 23:59:59' -- Up to April 29 to exclude mixed data with May
GROUP BY 1
ORDER BY 1;


-- Weekly Traffic Trends by Traffic Source
SELECT DATE_TRUNC('Week', created_at)::date AS weekly_date, -- Start of the week
       utm_source,
       utm_campaign,
       COUNT(website_session_id) AS total_traffic -- Total number of sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-29 23:59:59' -- Up to April 29 to exclude mixed data with May
GROUP BY 1, 2, 3
ORDER BY 2, 3, 1;


-- Weekly Traffic Trends for 'gsearch nonbrand' by Device Type 
SELECT DATE_TRUNC('Week', created_at)::date AS weekly_date, -- Start of the week
       device_type,
       COUNT(website_session_id) AS total_traffic -- Total number of sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-29 23:59:59' -- Up to April 29 to exclude mixed data with May
  AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY 1, 2
ORDER BY 2, 1;


-- Identify Top Traffic Source (by total sessions)
SELECT utm_source, utm_campaign,
       COUNT(*) AS total_traffic -- Total number of sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
GROUP BY 1, 2
ORDER BY 3 DESC;


-- Traffic Distribution for 'gsearch nonbrand' by Device Type
SELECT device_type,
       COUNT(*) AS total_traffic -- Total number of sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
  AND utm_source = 'gsearch' AND utm_campaign = 'nonbrand'
GROUP BY 1
ORDER BY 2 DESC;


-- Traffic Source Analysis by Total Orders, Conversion Rate, and Total Sales
SELECT ws.utm_source,
       ws.utm_campaign,
       COUNT(ws.website_session_id) AS total_sessions, -- Total number of sessions
       COUNT(o.website_session_id) AS total_orders, -- Total number of orders
       COUNT(o.website_session_id)::float / COUNT(ws.website_session_id) AS conversion_rate, -- Conversion rate
       SUM(o.items_purchased * o.price_usd) AS total_sales -- Total sales amount
FROM website_sessions AS ws
LEFT JOIN orders AS o
ON ws.website_session_id = o.website_session_id
WHERE ws.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
GROUP BY 1, 2
ORDER BY 6 DESC;


-- 'gsearch nonbrand' Total Orders, Conversion Rate, and Total Sales by Device Type
SELECT ws.device_type,
       COUNT(ws.website_session_id) AS total_sessions, -- Total number of sessions
       COUNT(o.website_session_id) AS total_orders, -- Total number of orders
       COUNT(o.website_session_id)::float / COUNT(ws.website_session_id) AS conversion_rate, -- Conversion rate
       SUM(o.items_purchased * o.price_usd) AS total_sales -- Total sales amount
FROM website_sessions AS ws
LEFT JOIN orders AS o
ON ws.website_session_id = o.website_session_id
WHERE ws.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
  AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY 1
ORDER BY 5 DESC;


-- Identify Top Landing Pages for 'gsearch nonbrand' Traffic
WITH page_rank AS -- CTE to rank pages viewed per session
    (
        SELECT created_at,   
               website_session_id,
               pageview_url,
               RANK() OVER (PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page
        FROM website_pageviews AS wp
        WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
          AND EXISTS 
            (
              SELECT 1 
              FROM website_sessions AS ws 
              WHERE wp.website_session_id = ws.website_session_id 
                AND ws.utm_source = 'gsearch' 
                AND ws.utm_campaign = 'nonbrand'
            )
    )

SELECT pr.pageview_url,
       COUNT(ws.website_session_id) AS total_landing_traffic -- Total sessions landing on the page
FROM website_sessions AS ws
JOIN page_rank AS pr
USING (website_session_id)
WHERE ws.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
  AND ws.is_repeat_session = 0
  AND rank_page = 1
GROUP BY 1
ORDER BY 2 DESC;


-- '/home' Landing Page Bounce Rate for 'gsearch nonbrand' Traffic
WITH page_rank AS -- CTE to rank pages viewed per session
    (
        SELECT created_at,   
               website_session_id,
               pageview_url,
               RANK() OVER (PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page 
        FROM website_pageviews AS wp
        WHERE created_at  BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
          AND EXISTS 
            (
              SELECT 1 
              FROM website_sessions AS ws 
              WHERE wp.website_session_id = ws.website_session_id 
                AND ws.utm_source = 'gsearch' 
                AND ws.utm_campaign = 'nonbrand'
            )
    ),
    
bounce_sessions AS -- CTE to identify bounce sessions
    (
        SELECT wp.website_session_id
        FROM website_pageviews AS wp
        WHERE wp.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
          AND EXISTS 
            (
              SELECT 1 
              FROM page_rank AS pr 
              WHERE wp.website_session_id = pr.website_session_id
                AND pr.rank_page = 1
                AND pr.pageview_url = '/home'
            )
        GROUP BY 1
        HAVING COUNT(wp.website_pageview_id) = 1 
    )

SELECT COUNT(CASE WHEN pr.rank_page = 1 AND pr.pageview_url = '/home' THEN pr.website_session_id END) AS total_sessions, -- Total sessions landing on '/home'
       COUNT(bs.website_session_id) AS total_bounces, -- Total bounce sessions
       COUNT(bs.website_session_id)::float / COUNT(CASE WHEN pr.rank_page = 1 AND pr.pageview_url = '/home' THEN pr.website_session_id END) AS bounce_rate -- Bounce rate
FROM page_rank AS pr
LEFT JOIN bounce_sessions AS bs
ON pr.website_session_id = bs.website_session_id
WHERE pr.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-04-30 23:59:59'
ORDER BY 1;


/*

CASE 2. Based on the first month's review, optimizations for the 'gsearch nonbrand' campaign and the '/home' landing page were implemented. 
The manager has requested a re-evaluation of the optimization results after one month (April 30 - May 31). 
These results will determine the next steps for further optimization.

*/

-- Weekly Traffic Trend Updates (April 30 - May 27)
SELECT DATE_TRUNC('Week', created_at)::date AS weekly_date, -- Using the start of the week
       COUNT(website_session_id) AS total_traffic -- Count total sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-04-30 00:00:00' AND '2012-05-27 23:59:59' -- Until May 27 because the 28th - 31st have entered a new week mixed with June data
GROUP BY 1
ORDER BY 1;

-- Update on '/home' Page Bounce Rate
WITH page_rank AS -- CTE To rank pages viewed per session
    (
        SELECT created_at,   
               website_session_id,
               pageview_url,
               RANK() OVER (PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page
        FROM website_pageviews AS wp
        WHERE created_at BETWEEN '2012-04-30 00:00:00' AND '2012-05-31 23:59:59'
        AND EXISTS 
               (SELECT 1 
                FROM website_sessions AS ws 
                WHERE wp.website_session_id = ws.website_session_id 
                AND ws.utm_source = 'gsearch' 
                AND ws.utm_campaign = 'nonbrand')
    ),
    
bounce_sessions AS -- CTE To identify bounce sessions
    (
        SELECT wp.website_session_id
        FROM website_pageviews AS wp
        WHERE wp.created_at BETWEEN '2012-04-30 00:00:00' AND '2012-05-31 23:59:59'
        AND EXISTS
            (SELECT 1 
             FROM page_rank AS pr 
             WHERE wp.website_session_id = pr.website_session_id
             AND pr.rank_page = 1
             AND pr.pageview_url = '/home')
        GROUP BY 1
        HAVING COUNT(wp.website_pageview_id) = 1
    )

SELECT COUNT(CASE WHEN pr.rank_page = 1 AND pr.pageview_url = '/home' THEN pr.website_session_id END) AS total_session, -- Count total sessions
       COUNT(bs.website_session_id) AS total_bounce, -- Count total bounce sessions
       COUNT(bs.website_session_id)::float/COUNT(CASE WHEN pr.rank_page = 1 AND pr.pageview_url = '/home' THEN pr.website_session_id END) AS bounce_rate -- Calculate bounce rate
FROM page_rank AS pr
LEFT JOIN bounce_sessions AS bs
ON pr.website_session_id = bs.website_session_id
WHERE pr.created_at BETWEEN '2012-04-30 00:00:00' AND '2012-05-31 23:59:59'
ORDER BY 1;

-- Update on 'gsearch nonbrand' Total Orders, Conversion Rate, and Total Sales
SELECT ws.utm_source,
       ws.utm_campaign,
       COUNT(ws.website_session_id) AS total_session, -- Count total sessions
       COUNT(o.website_session_id) AS total_order, -- Count total orders
       COUNT(o.website_session_id)::float/COUNT(ws.website_session_id) AS conversion_rate, -- Calculate conversion rate
       SUM(o.items_purchased * o.price_usd) AS total_sales -- Calculate total sales
FROM website_sessions AS ws
LEFT JOIN orders AS o
ON ws.website_session_id = o.website_session_id
WHERE ws.created_at BETWEEN '2012-04-30 00:00:00' AND '2012-05-31 23:59:59'
AND ws.utm_source = 'gsearch' AND ws.utm_campaign = 'nonbrand'
GROUP BY 1,2
ORDER BY 6 DESC;


/*

CASE 3. With the '/home' landing page optimization showing no results, the manager decided to conduct A/B testing 
for a new landing page named '/lander-1' for 'gsearch nonbrand' traffic. 
This landing page was launched on June 19, and the A/B test ran for one month (June 19 - July 31).

*/

-- 
WITH page_rank AS -- CTE to rank pages viewed per session
	(
		SELECT created_at,	
				website_session_id,
				pageview_url,
				RANK()OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page
		FROM website_pageviews AS wp
		WHERE created_at  BETWEEN '2012-06-19 00:00:00' AND '2012-07-31 23:59:59'
		AND EXISTS 
				(SELECT 1 
				FROM website_sessions AS ws 
				WHERE wp.website_session_id = ws.website_session_id 
				AND ws.utm_source = 'gsearch' 
				AND ws.utm_campaign = 'nonbrand')
	),
	
bounce_sessions AS -- CTE to identify bounce sessions
	(
		SELECT wp.website_session_id
		FROM website_pageviews AS wp
		WHERE wp.created_at BETWEEN '2012-06-19 00:00:00' AND '2012-07-31 23:59:59'
		AND EXISTS 
			(SELECT 1 
			FROM page_rank AS pr 
			WHERE wp.website_session_id = pr.website_session_id
			AND pr.rank_page = 1
			AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1'))
		GROUP BY 1
		HAVING COUNT(wp.website_pageview_id) = 1 
	)
	
SELECT pr.pageview_url,
		COUNT(CASE WHEN pr.rank_page = 1 AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1') THEN pr.website_session_id END) AS total_session, -- Count total sessions
		COUNT(bs.website_session_id) AS total_bounce, -- Count total bounce sessions
		COUNT(bs.website_session_id)::float / COUNT(CASE WHEN pr.rank_page = 1 AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1') THEN pr.website_session_id END) AS bounce_rate -- Calculate bounce rate
FROM page_rank AS pr
LEFT JOIN bounce_sessions AS bs
ON pr.website_session_id = bs.website_session_id
WHERE pr.created_at BETWEEN '2012-06-19 00:00:00' AND '2012-07-31 23:59:59'
AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1')
GROUP BY 1
ORDER BY 1;


-- Performance of each Landing Page based on Total Orders, Conversion Rate, and Total Sales
WITH page_rank AS -- CTE to rank pages viewed per session
	(
		SELECT created_at,	
				website_session_id,
				pageview_url,
				RANK()OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page
		FROM website_pageviews AS wp
		WHERE created_at BETWEEN '2012-06-19 00:00:00' AND '2012-07-31 23:59:59'
		AND EXISTS 
				(SELECT 1 
				FROM website_sessions AS ws 
				WHERE wp.website_session_id = ws.website_session_id 
				AND ws.utm_source = 'gsearch' 
				AND ws.utm_campaign = 'nonbrand')
	),

each_lp_order AS -- CTE to calculate sales for each landing page
	(
		SELECT pr.website_session_id,
				SUM(o.items_purchased * o.price_usd) AS sales -- Calculate total sales
		FROM orders AS o
		JOIN page_rank AS pr
		USING (website_session_id)
		WHERE pr.rank_page = 1
		AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1')
		GROUP BY 1
	)

SELECT pr.pageview_url,
		COUNT(pr.website_session_id) AS total_session, -- Count total sessions
		COUNT(o.website_session_id) AS total_order, -- Count total orders
		COUNT(o.website_session_id)::float / COUNT(pr.website_session_id) AS conversion_rate, -- Calculate conversion rate
		SUM(sales) AS total_sales -- Calculate total sales
FROM page_rank AS pr
LEFT JOIN each_lp_order AS o
ON pr.website_session_id = o.website_session_id
WHERE pr.rank_page = 1 AND (pr.pageview_url = '/home' OR pr.pageview_url = '/lander-1')
GROUP BY 1
ORDER BY 4 DESC;


/*

CASE 4. After optimizing the performance of the 'gsearch nonbrand' campaign and landing page, 
the manager directed us to conduct a comprehensive funnel analysis for all traffic sources to identify pages with high exit rates. 
The manager also wants to understand when traffic starts to peak on the website to gain better insights into traffic behavior.
(19 March - 31 July)

*/

-- Using Recursive CTE for Funnel Analysis
WITH RECURSIVE funnel AS 
    (
        -- Base: Retrieve landing pages for each session
        SELECT 
            website_session_id,
            pageview_url,
            funnel_step,
            user_page_step,
            CASE 
                WHEN funnel_step = 1 AND user_page_step = 1 THEN 1 -- Marks the landing page as a valid step
                ELSE NULL 
            END AS is_valid_step
        FROM
        (
            -- Establish the order of the funnel from start to finish
            SELECT 
                website_session_id,
                pageview_url,
                CASE 
                    WHEN pageview_url = '/home' OR pageview_url = '/lander-1' THEN 1 
                    WHEN pageview_url = '/products' THEN 2 
                    WHEN pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear', '/the-birthday-sugar-panda') THEN 3 
                    WHEN pageview_url = '/cart' THEN 4 
                    WHEN pageview_url = '/shipping' THEN 5 
                    WHEN pageview_url = '/billing' THEN 6 
                    WHEN pageview_url = '/thank-you-for-your-order' THEN 7 
                    ELSE NULL 
                END AS funnel_step,
                RANK() OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS user_page_step -- Identifies the order of pages viewed by users with a ranking
            FROM website_pageviews
            WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59' 
        ) AS base
        WHERE funnel_step = 1 -- Choose only the first step (landing page)

        UNION ALL

        -- Recursive case: Proceed to the next step in the funnel
        SELECT 
            f.website_session_id,
            b.pageview_url,
            b.funnel_step,
            b.user_page_step,
            CASE 
                WHEN f.is_valid_step = 1 THEN 1 -- Marking step as valid
                ELSE NULL 
            END AS is_valid_step
        FROM funnel AS f
        JOIN
        (
            -- Retrieve all subsequent pages in the same session
            SELECT 
                website_session_id,
                pageview_url,
                CASE 
                    WHEN pageview_url = '/home' OR pageview_url = '/lander-1' THEN 1
                    WHEN pageview_url = '/products' THEN 2
                    WHEN pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear', '/the-birthday-sugar-panda') THEN 3
                    WHEN pageview_url = '/cart' THEN 4
                    WHEN pageview_url = '/shipping' THEN 5
                    WHEN pageview_url = '/billing' THEN 6
                    WHEN pageview_url = '/thank-you-for-your-order' THEN 7
                    ELSE NULL
                END AS funnel_step,
                RANK() OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS user_page_step
            FROM website_pageviews
            WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59' 
        ) AS b
        ON f.website_session_id = b.website_session_id 
        AND b.user_page_step = f.user_page_step + 1 -- Ensure the next steps are in order
        AND b.funnel_step = f.funnel_step + 1 -- Ensure the next step is within the funnel
    )
    
SELECT 
    COUNT(DISTINCT CASE WHEN f.funnel_step = 1 THEN wp.website_session_id END) AS total_sessions, -- Count total sessions for the landing page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 2 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 1 THEN wp.website_session_id END)) AS lp_exit_rate, -- Count exit rate for the landing page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 2 THEN f.website_session_id END) AS product_sessions, -- Count total sessions that reach the product page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 3 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 2 THEN f.website_session_id END)) AS prod_exit_rate, -- Count exit rate for the product page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 3 THEN f.website_session_id END) AS proddetail_sessions, -- Count total sessions that reach the product detail page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 4 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 3 THEN f.website_session_id END)) AS proddetail_exit_rate, -- Count exit rate for the product detail page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 4 THEN f.website_session_id END) AS cart_sessions, -- Count total sessions that reach the cart page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 5 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 4 THEN f.website_session_id END)) AS cart_exit_rate, -- Count exit rate for the cart page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 5 THEN f.website_session_id END) AS shipping_sessions, -- Count total sessions that reach the shipping page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 6 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 5 THEN f.website_session_id END)) AS shipping_exit_rate, -- Count exit rate for the shipping page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 6 THEN f.website_session_id END) AS billing_sessions, -- Count total sessions that reach the billing page
    1 - (COUNT(DISTINCT CASE WHEN f.funnel_step = 7 THEN f.website_session_id END)::float / 
         COUNT(DISTINCT CASE WHEN f.funnel_step = 6 THEN f.website_session_id END)) AS billing_exit_rate, -- Count exit rate for the billing page
    COUNT(DISTINCT CASE WHEN f.funnel_step = 7 THEN f.website_session_id END) AS thanks_sessions -- Count total sessions that reach the thank-you page
FROM funnel AS f
JOIN website_pageviews AS wp
ON f.website_session_id = wp.website_session_id
AND wp.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59' 
WHERE f.is_valid_step IS NOT NULL; -- Only includes valid steps


-- Traffic Peak Time Analysis
WITH time_data AS -- CTE for data on when session traffic peaks
	(
		SELECT website_session_id,
				created_at,
				TRIM(TO_CHAR(created_at, 'day')) AS day, -- Get the name of the day
				 CASE -- Get the hour
		           WHEN EXTRACT(HOUR FROM created_at) = 0 THEN 24
		           ELSE EXTRACT(HOUR FROM created_at)
		       END AS hour
		FROM website_sessions
		WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59'
	)

SELECT day,
		hour,
		COUNT(website_session_id) AS total_traffic -- Count total sessions
FROM time_data
GROUP BY 1,2
ORDER BY 1,2;


/*

WEBSITE SCORE CARD (March 19 - December 31)

*/

WITH user_min_date AS -- CTE for user's initial time accessing website
(
    SELECT user_id,
           MIN(created_at) AS start_date -- getting the initial date
    FROM website_sessions
    WHERE created_at BETWEEN '2012-01-01' AND '2012-12-31'
    AND is_repeat_session = 0 
    GROUP BY 1
),

bounce_sessions AS -- CTE for bounce sessions for all traffic source
(
    SELECT website_session_id
    FROM website_pageviews
    WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59'
    GROUP BY 1
    HAVING COUNT (website_pageview_id) = 1 
),

session_duration AS -- CTE for time duration on the website for each active session (viewed > 1 page)
(
    SELECT website_session_id,
           EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at)))/60 AS duration -- session duration in minutes
    FROM website_pageviews AS wp
    WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59'
    AND NOT EXISTS
        (SELECT 1 FROM bounce_sessions AS bs WHERE wp.website_session_id = bs.website_session_id) -- ignoring bounce sessions
    GROUP BY 1
    HAVING (EXTRACT(EPOCH FROM (MAX(wp.created_at) - MIN(wp.created_at))) / 60 < 1440  -- anticipate outliers (duration more than 1 day or less than 1 minute)
    OR EXTRACT(EPOCH FROM (MAX(wp.created_at) - MIN(wp.created_at))) / 60 > 1)
    ORDER BY 1
),
	
page_persession AS -- CTE for total page viewed for each session
(
    SELECT website_session_id,
           COUNT(website_pageview_id) AS total_page -- count total page for each session
    FROM website_pageviews AS wp
    WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59'
    AND NOT EXISTS
        (SELECT 1 FROM bounce_sessions AS bs WHERE wp.website_session_id = bs.website_session_id) -- ignoring bounce sessions
    GROUP BY 1
)

SELECT 
    COUNT(DISTINCT ws.user_id) AS total_user, -- count total unique users
    COUNT(DISTINCT CASE WHEN ws.is_repeat_session = 1 THEN ws.user_id END) AS repeat_user, -- count total users that have repeat session
    COUNT(ws.website_session_id) AS total_session, -- count total sessions
    COUNT(CASE WHEN bs.website_session_id IS NULL THEN ws.website_session_id END) AS active_session, -- count total active sessions
    COUNT(CASE WHEN bs.website_session_id IS NOT NULL THEN ws.website_session_id END) AS bounce_session, -- count total bounce sessions
    ROUND(SUM(duration)/COUNT(CASE WHEN duration IS NOT NULL THEN ws.website_session_id END),2) AS avg_session_duration, -- calculate the average duration per session (active sessions only)
    ROUND(SUM(total_page)/COUNT(CASE WHEN total_page IS NOT NULL THEN ws.website_session_id END),2) AS avg_page_session, -- calculate the average number of pages per session (active sessions only)
    (COUNT(o.website_session_id)::float/COUNT(ws.website_session_id))*100 AS conversion_rate, -- calculate conversion rate
    SUM(items_purchased * price_usd) AS total_sales, -- calculate total sales
    SUM(items_purchased * price_usd) - SUM(items_purchased * cogs_usd) AS total_revenue -- calculate total revenue
FROM website_sessions AS ws
LEFT JOIN user_min_date AS umd
    ON ws.user_id = umd.user_id AND ws.created_at = umd.start_date
LEFT JOIN bounce_sessions AS bs
    ON ws.website_session_id = bs.website_session_id
LEFT JOIN session_duration AS sd 
    ON ws.website_session_id = sd.website_session_id
LEFT JOIN page_persession AS pp
    ON ws.website_session_id = pp.website_session_id
LEFT JOIN orders AS o
    ON ws.website_session_id = o.website_session_id
WHERE ws.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-07-31 23:59:59'
ORDER BY 1;


/*

Creating Materialized Views for Visualization

*/


-- Master Table
CREATE MATERIALIZED VIEW master_table AS
WITH bounce_sessions AS
(
    SELECT website_session_id
    FROM website_pageviews
    WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-12-31 23:59:59'
    GROUP BY 1
    HAVING COUNT (website_pageview_id) = 1
),

page_rank AS
	(
		SELECT created_at,	
				website_session_id,
				pageview_url,
				RANK()OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS rank_page
		FROM website_pageviews AS wp
		WHERE created_at  BETWEEN '2012-03-19 00:00:00' AND '2012-12-31 23:59:59'
	),
	
session_landing_page AS
	(
	SELECT *
	FROM page_rank
	WHERE rank_page = 1	
	)

SELECT ws.user_id,
		ws.website_session_id,
		ws.created_at,
		ws.is_repeat_session,
		ws.utm_source,
		ws.utm_campaign,
		ws.device_type,
		CASE WHEN bs.website_session_id IS NULL THEN 'active session'
			WHEN bs.website_session_id IS NOT NULL THEN 'bounce_session'
			ELSE NULL
		END AS is_bounce,
		slp.pageview_url as landing_page,
		CASE WHEN o.website_session_id IS NOT NULL THEN 'convert'
			ELSE NULL
		END AS is_convert
FROM website_sessions AS ws
JOIN session_landing_page AS slp
ON ws.website_session_id = slp.website_session_id
LEFT JOIN bounce_sessions as bs
ON ws.website_session_id = bs.website_session_id
LEFT JOIN orders AS o
ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at BETWEEN '2012-03-19 00:00:00' AND '2012-12-31 23:59:59'
ORDER BY 1,2;


-- Funnel Table
CREATE MATERIALIZED VIEW funnel_table AS
WITH RECURSIVE funnel AS 
    (
        SELECT 
            website_session_id,
            pageview_url,
            funnel_step,
            user_page_step,
            CASE 
                WHEN funnel_step = 1 AND user_page_step = 1 THEN 1
                ELSE NULL 
            END AS is_valid_step
        FROM
        (
            SELECT 
                website_session_id,
                pageview_url,
                CASE 
                    WHEN pageview_url = '/home' OR pageview_url = '/lander-1' THEN 1 
                    WHEN pageview_url = '/products' THEN 2 
                    WHEN pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear', '/the-birthday-sugar-panda') THEN 3 
                    WHEN pageview_url = '/cart' THEN 4 
                    WHEN pageview_url = '/shipping' THEN 5 
                    WHEN pageview_url = '/billing' THEN 6 
                    WHEN pageview_url = '/thank-you-for-your-order' THEN 7 
                    ELSE NULL 
                END AS funnel_step,
                RANK() OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS user_page_step
            FROM website_pageviews
            WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-12-31 23:59:59'
        ) AS base
        WHERE funnel_step = 1

        UNION ALL

        SELECT 
            f.website_session_id,
            b.pageview_url,
            b.funnel_step,
            b.user_page_step,
            CASE 
                WHEN f.is_valid_step = 1 THEN 1
                ELSE NULL 
            END AS is_valid_step
        FROM funnel AS f
        JOIN
        (
            SELECT 
                website_session_id,
                pageview_url,
                CASE 
                    WHEN pageview_url = '/home' OR pageview_url = '/lander-1' THEN 1
                    WHEN pageview_url = '/products' THEN 2
                    WHEN pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear', '/the-birthday-sugar-panda') THEN 3
                    WHEN pageview_url = '/cart' THEN 4
                    WHEN pageview_url = '/shipping' THEN 5
                    WHEN pageview_url = '/billing' THEN 6
                    WHEN pageview_url = '/thank-you-for-your-order' THEN 7
                    ELSE NULL
                END AS funnel_step,
                RANK() OVER(PARTITION BY website_session_id ORDER BY website_pageview_id) AS user_page_step
            FROM website_pageviews
            WHERE created_at BETWEEN '2012-03-19 00:00:00' AND '2012-12-31 23:59:59'
        ) AS b
        ON f.website_session_id = b.website_session_id 
        AND b.user_page_step = f.user_page_step + 1
        AND b.funnel_step = f.funnel_step + 1 
    )
	
SELECT * 
FROM funnel
ORDER BY 1, 3;