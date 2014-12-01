USE [bodb_Report]
GO


ALTER PROCEDURE [dbo].[Task_rptDepwinlostByProduct_MERGE] 		
	@strXML varchar(max)
AS
/*   
 Task : Summary data for deposit member  
 DB: DB06.bodb_report
 Revisions:   
  - 20120930@viet: create SP   
  - 20141120@Don: Adjustment to serve to change KeenOcean's currency RMB to HK$
                 
 Param's Explanation:  
 • @winlostdate: The date need to summary  
*/  
SET NOCOUNT ON
SET DEADLOCK_PRIORITY LOW	

IF @strXML IS NULL OR EXISTS(SELECT 1 FROM bodb02.dbo.SystemSettings WITH(NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingDEPdata')
BEGIN	
	RETURN
END

declare @_hdoc int	
EXEC sp_xml_preparedocument @_hdoc OUTPUT, @strXML

SELECT winlostdate
	,custid
	,sporttype
	,turnover
	,drawTO
	,winlost
	,playercomm
	,BetCount
	,Outstanding
	,currency
INTO #TEMP	
FROM OPENXML(@_hdoc,'/root/r',2) 
WITH (
	winlostdate datetime '@c1'	
	,custid int '@c2'
	,sporttype smallint '@c3'
	,turnover money '@c4'
	,drawTO money '@c5'
	,winlost money '@c6'
	,playercomm money '@c7'
	,BetCount int '@c8'
	,Outstanding money '@c9'
	,currency int '@d0'
 ) 
 
exec sp_xml_removedocument @_hdoc	
 
declare @updated_list as table(custid int, winlostdate smalldatetime, sporttype smallint)
UPDATE d
	SET turnover = s.turnover
		,drawTO = s.drawTO
		,winlost = s.winlost
		,playercomm = s.playercomm
		,BetCount = s.BetCount
		,Outstanding = s.Outstanding
OUTPUT inserted.custid, inserted.winlostdate, inserted.sporttype into @updated_list		
FROM dbo.rptDepWinlostbyproduct d WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #TEMP s on d.custid = s.custid and d.winlostdate = s.winlostdate and d.sporttype = s.sporttype

DELETE D
FROM #TEMP D
	INNER JOIN @updated_list s on d.custid = s.custid and d.winlostdate = s.winlostdate and d.sporttype = s.sporttype

INSERT INTO dbo.rptDepWinlostbyproduct (
	winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, BetCount, Outstanding
)
SELECT winlostdate, custid, sporttype, currency, turnover, drawTO, winlost, playercomm, BetCount, Outstanding
FROM #TEMP

DROP TABLE #TEMP
--SET NOCOUNT OFF