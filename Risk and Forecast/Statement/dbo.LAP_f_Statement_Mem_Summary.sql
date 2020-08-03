/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION dbo.LAP_f_Statement_Mem_Summary(
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME
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
	
Param's Explanation:     
*/
RETURN (
	SELECT orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission
	FROM (
		SELECT CAST(CAST(@FromDate AS DATE) AS SMALLDATETIME) AS FromDate
			, DATEADD(MINUTE, -1, DATEADD(DAY, 1, CAST(CAST(@ToDate AS DATE) AS SMALLDATETIME))) AS ToDate
			, @CustID AS custid
			, 0 AS BAL_KEY
			, 2 AS VOID_KEY
			, 1 AS BET_KEY
			, 2 AS TRAN_KEY
			, 4 AS PROMO_KEY
	) AS temp
	CROSS APPLY (
		SELECT 
			orderkey
			, winlostdate
			, transtype
			, transdesc
			, SUM(turnover)		AS turnover
			, SUM(TotalAmt)		AS TotalAmt
			, SUM(commission)	AS Commission
		FROM (
			-- bet TO summary
			SELECT 
				CASE 
					WHEN b.statusID IN (101,102,103) AND b.bettype NOT IN (17000, 17003) THEN temp.VOID_KEY --> Void/Reject/Refund
					WHEN b.bettype IN (17000, 17003) THEN temp.PROMO_KEY
					ELSE temp.BET_KEY --> Won/Lose/Draw
				END AS orderkey
				, winlostdate
				, CASE WHEN bettype IN (17000, 17003) THEN 'PROMO' ELSE 'BET' END AS transtype
				, NULL AS transdesc
				, SUM(b.stake) AS turnover
				, SUM(b.winlost - b.actual_stake) AS TotalAmt
				, SUM(b.playercomm) AS commission
			FROM bodb_archive.dbo.bettrans_bk b (NOLOCK)
			WHERE 
				b.custid			= temp.custid
				AND b.winlostdate	>= temp.FromDate AND b.winlostdate <= temp.ToDate

			GROUP BY
				CASE 
					WHEN b.statusID IN (101,102,103) AND b.bettype NOT IN (17000, 17003) THEN 2 --> Void/Reject/Refund
					WHEN b.bettype IN (17000, 17003) THEN temp.PROMO_KEY
					ELSE temp.BET_KEY --> Won/Lose/Draw
				END,
				 b.winlostdate,
				CASE WHEN bettype IN (17000, 17003) THEN 'PROMO' ELSE 'BET' END

			-- BAL
			UNION ALL
			SELECT temp.BAL_KEY
				, rpt.AccDate
				, UPPER(rpt.transtype)
				, NULL
				, 0
				, rpt.TotalAmt 
				, 0
			FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
			WHERE 
				rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate <= temp.ToDate 
				AND rpt.transtype IN ('BAL')  

			-- transactions
			UNION ALL
			SELECT temp.TRAN_KEY
				, rpt.AccDate
				, UPPER(rpt.transtype)
				, ISNULL(rpt.transdesc,'')
				, 0
				, rpt.TotalAmt 
				, 0
			FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
			WHERE 
				rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate <= temp.ToDate 
				AND rpt.transtype NOT IN ('BAL', 'BET', 'COM')  
		) AS rpt
		GROUP BY 
			rpt.winlostdate
			, rpt.orderkey
			, rpt.transtype
			, rpt.transdesc
	) AS rpt
)
GO


