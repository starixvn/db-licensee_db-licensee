/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.LAP_f_Statement_Mem_Summary
(
	  @CustID INT
	, @FromDate SMALLDATETIME
	, @ToDate SMALLDATETIME
	, @PromoBettypes VARCHAR(MAX)
)
RETURNS TABLE
AS
/*
Created:Bobby@20190723   
Task : 112658 - LAP - Customer Statement - Summary
DB: DBACC/bodb02

Revisions:  
	- 20190723@Bobby: Initialize [RedmineID: #117534]
	- 20190904@Bobby: Implement Statement Service - Level 1 [RedmineID: #119648]
	- 20191003@Bobby: Integrate NPH Promotion product [RedmineID: #120333]
	- 20200803@Sophia: add Saba Loyalty [Redmine: #138493]
	- 20210203@Louis: Saba Red Envelope [RedmineID: #149923]
	- 20241701@Evan: Integrate Saba Reward Risk-free Rebate + add missing bettype 17006 [RedmineID: #201886]
	- 20240503@Kelvin: LAP - Player Administration - Statement - Missing data in Statement [RedmineID: #204744]
	- 20240416@Evan: Integrate Saba Coins - add param @PromoBettypes [RedmineID: #202281]
	
Param's Explanation:     
*/
RETURN (
WITH temp AS
(
	SELECT CAST(CAST(@FromDate AS DATE) AS SMALLDATETIME) AS FromDate
			, DATEADD(DAY, 1, CAST(CAST(@ToDate AS DATE) AS SMALLDATETIME)) AS ToDate
		 , @CustID AS custid
		 , 0 AS BAL_KEY
		 , 2 AS VOID_KEY
		 , 1 AS BET_KEY
		 , 2 AS TRAN_KEY
		 , 4 AS PROMO_KEY
),
cte_PromoBettypes AS
(
	SELECT CAST(value AS SMALLINT) AS bettype
	FROM STRING_SPLIT(@PromoBettypes, ',')
)
SELECT orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission
FROM temp
	CROSS APPLY (
		SELECT orderkey
			 , winlostdate
			 , transtype
			 , transdesc
			 , SUM(turnover) AS turnover
			 , SUM(TotalAmt) AS TotalAmt
			 , SUM(commission) AS Commission
		FROM (
			-- bet TO summary
			SELECT CASE
					   WHEN b.statusID IN (101, 102, 103) AND
						   s.bettype IS NULL THEN temp.VOID_KEY --> Void/Reject/Refund
					   WHEN s.bettype IS NOT NULL THEN temp.PROMO_KEY
					   ELSE temp.BET_KEY --> Won/Lose/Draw
				   END AS orderkey
				 , winlostdate
				 , CASE
					   WHEN s.bettype IS NOT NULL THEN 'PROMO'
					   ELSE 'BET'
				   END AS transtype
				 , NULL AS transdesc
				 , SUM(b.stake) AS turnover
				 , SUM(b.winlost - b.actual_stake) AS TotalAmt
				 , SUM(b.playercomm) AS commission
			FROM bodb_Archive.dbo.bettrans_bk b (NOLOCK)
				LEFT JOIN cte_PromoBettypes s ON s.bettype = b.bettype
			WHERE b.custid = temp.custid
				AND b.winlostdate >= temp.FromDate AND b.winlostdate < temp.ToDate
			GROUP BY CASE
						 WHEN b.statusID IN (101, 102, 103) AND
							 s.bettype IS NULL THEN 2 --> Void/Reject/Refund
						 WHEN s.bettype IS NOT NULL THEN temp.PROMO_KEY
						 ELSE temp.BET_KEY --> Won/Lose/Draw
					 END
				   , b.winlostdate
				   , CASE
						 WHEN s.bettype IS NOT NULL THEN 'PROMO'
						 ELSE 'BET'
					 END

			-- BAL
			UNION ALL
			SELECT temp.BAL_KEY
				 , rpt.accdate
				 , UPPER(rpt.transtype)
				 , NULL
				 , 0
				 , rpt.TotalAmt
				 , 0
			FROM bodb_Report.dbo.[Statement] rpt WITH (NOLOCK)
			WHERE rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate < temp.ToDate 
				AND rpt.transtype IN ('BAL')

			-- transactions
			UNION ALL
			SELECT temp.TRAN_KEY
				 , rpt.accdate
				 , UPPER(rpt.transtype)
				 , ISNULL(rpt.transdesc, '')
				 , 0
				 , rpt.TotalAmt
				 , 0
			FROM bodb_Report.dbo.[Statement] rpt WITH (NOLOCK)
			WHERE rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate < temp.ToDate 
				AND rpt.transtype NOT IN ('BAL', 'BET', 'COM')
		) AS rpt
		GROUP BY rpt.winlostdate
			   , rpt.orderkey
			   , rpt.transtype
			   , rpt.transdesc
	) AS rpt
)
GO