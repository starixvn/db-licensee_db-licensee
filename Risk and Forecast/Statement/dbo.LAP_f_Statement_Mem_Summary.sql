/*<info serverAlias="DBRPT-bodb02" executers="" viewers="" isFunction="1" isNested="1"></info>*/
CREATE FUNCTION dbo.LAP_f_Statement_Mem_Summary(
	@CustID			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME
)
RETURNS TABLE
AS
/*
Created:Bobby@20190723   
Task : 112658 - LAP - Customer Statement - Summary
DB: DBEXT/bodb02

Revisions:  
	- 20190723@Bobby: Initialize [RedmineID: #117534]
	
Param's Explanation:     
*/
RETURN (
	SELECT orderkey, winlostdate, transtype, transdesc, turnover,TotalAmt,commission, balance
	FROM (
		SELECT CAST(CAST(@FromDate AS DATE) AS SMALLDATETIME) AS FromDate
			, DATEADD(MINUTE, -1, DATEADD(DAY, 1, CAST(CAST(@ToDate AS DATE) AS SMALLDATETIME))) AS ToDate
			, srecommend
			, mrecommend
			, recommend
			, custid
		FROM bodb02.dbo.custInfo WITH(NOLOCK)
		WHERE 
			custid = @CustID
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
			, SUM(balance)		AS Balance
		FROM (
			-- bet TO summary
			SELECT 1 AS orderkey
				, winlostdate
				, 'BET' AS transtype
				, NULL AS transdesc
				, SUM(b.stake) AS turnover
				, 0 AS TotalAmt
				, 0 AS commission
				, NULL AS balance
			FROM bodb_archive.dbo.bettrans_bk b (NOLOCK)
			WHERE 
				b.winlostdate		>= temp.FromDate AND b.winlostdate <= temp.ToDate
				AND b.custid		= temp.custid
				--AND rpt.srecommend	= temp.srecommend
				--AND rpt.mrecommend	= temp.mrecommend
				--AND rpt.recommend	= temp.recommend
			GROUP BY b.winlostdate
				

			-- bet amt/comm summary
			UNION ALL
			SELECT 1 
				, AccDate
				, 'BET'
				, NULL
				, 0
				, CASE rpt.transtype WHEN 'BET' THEN rpt.TotalAmt ELSE 0 END
				, CASE rpt.transtype WHEN 'COM' THEN rpt.TotalAmt ELSE 0 END
				, NULL
			FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
			WHERE 
				rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate <= temp.ToDate 
				AND rpt.transtype IN ('BET', 'COM')  

			-- transactions
			UNION ALL
			SELECT CASE rpt.transtype WHEN 'BAL' THEN 0 ELSE 2 END 
				, rpt.AccDate
				, UPPER(rpt.transtype)
				, ISNULL(rpt.transdesc,'')
				, 0
				, CASE rpt.transtype WHEN 'BAL' THEN NULL ELSE rpt.TotalAmt END 
				, 0
				, CASE rpt.transtype WHEN 'BAL' THEN rpt.TotalAmt ELSE NULL END 
			FROM bodb_report.dbo.[Statement] rpt WITH (NOLOCK)  
			WHERE 
				rpt.custid = @CustID
				AND rpt.accdate >= temp.FromDate AND rpt.accdate <= temp.ToDate 
				AND rpt.transtype NOT IN ('BET', 'COM')  
		) AS rpt
		GROUP BY 
			rpt.winlostdate
			, rpt.orderkey
			, rpt.transtype
			, rpt.transdesc
	) AS rpt
)
GO


