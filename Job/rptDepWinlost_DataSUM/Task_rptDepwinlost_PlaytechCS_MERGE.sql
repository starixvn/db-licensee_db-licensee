USE [bodb_Report]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_rptDepwinlost_PlaytechCS_MERGE] 		
	@strXML varchar(max)
AS
/*   
 Task : Summary data for deposit member  
 DB: DBRPT.bodb_report
 Revisions:   
  - 20140514@Victor: create SP  
  - 20140528@Victor: remove NetGaming column 
                 
 Param's Explanation:  
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
	,drawBetCount
	,Outstanding
	,PShare
	,PWin
INTO #TEMP	
FROM OPENXML(@_hdoc,'/root/r',2) 
WITH (
	winlostdate datetime '@d8'	
	,custid int '@d9'
	,sporttype smallint '@e0'
	,turnover money '@e1'
	,drawTO money '@e2'
	,winlost money '@e3'
	,playercomm money '@e4'
	,BetCount int '@e5'
	,drawBetCount int '@e6'
	,Outstanding money '@e7'
	,PShare money '@e8'
	,PWin money '@e9'
 ) 
 
exec sp_xml_removedocument @_hdoc	
 
declare @updated_list as table(custid int, winlostdate smalldatetime, sporttype smallint)
UPDATE d
	SET turnover = s.turnover
		,drawTO = s.drawTO
		,winlost = s.winlost
		,playercomm = s.playercomm
		,BetCount = s.BetCount
		,drawBetCount = s.drawBetCount
		,Outstanding = s.Outstanding
		,ProgressiveShare = s.PShare
		,ProgressiveWin = s.PWin
OUTPUT inserted.custid, inserted.winlostdate, inserted.sporttype into @updated_list		
FROM dbo.rptDepwinlost_PlaytechCS d WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #TEMP s on d.custid = s.custid and d.winlostdate = s.winlostdate and d.sporttype = s.sporttype

DELETE D
FROM #TEMP D
	INNER JOIN @updated_list s on d.custid = s.custid and d.winlostdate = s.winlostdate and d.sporttype = s.sporttype

INSERT INTO dbo.rptDepwinlost_PlaytechCS (
	winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount , Outstanding, ProgressiveShare, ProgressiveWin
)
SELECT winlostdate, custid, sporttype, turnover, drawTO, winlost, playercomm, BetCount, drawBetCount, Outstanding, PShare, PWin
FROM #TEMP

DROP TABLE #TEMP
SET NOCOUNT OFF