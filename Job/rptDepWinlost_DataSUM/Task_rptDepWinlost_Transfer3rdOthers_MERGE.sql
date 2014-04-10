USE [bodb_Report]
GO
/****** Object:  StoredProcedure [dbo].[Task_rptDepWinlost_Transfer3rdOthers_MERGE]    Script Date: 04/09/2014 21:17:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Task_rptDepWinlost_Transfer3rdOthers_MERGE] 	
	@strXML varchar(MAX)
AS
/*   
 Task : Summary data for deposit member  
 DB: DB06.bodb_report
 Revisions:   
	- 20130626@Don: Creating SP
                 
 Param's Explanation:  

*/  
SET NOCOUNT ON
SET DEADLOCK_PRIORITY LOW	

--IF @strXML IS NULL OR EXISTS(SELECT 1 FROM bodb02.dbo.SystemSettings WITH(NOLOCK) WHERE VValue = 1 AND VName = 'isCalculatingDEPdata')
--BEGIN	
--	RETURN
--END

DECLARE @_xml XML
SELECT @_xml = CONVERT(XML, @strXML)
SELECT	
	CAST(T.C.value('./@d0', 'int') as smalldatetime) winlostdate, 
	T.C.value('./@d1', 'int') custid, 
	T.C.value('./@d2', 'int') currency,
	T.C.value('./@d3', 'int') partnerid,
	T.C.value('./@d4', 'int') recommend,
	T.C.value('./@d5', 'int') mrecommend,
	T.C.value('./@d6', 'int') srecommend,
	ISNULL(T.C.value('./@d7', 'money'), 0) transferamount
INTO #TEMP		
FROM @_xml.nodes('/root/r') AS [T](C)

DECLARE @updated_list AS TABLE(custid int, winlostdate smalldatetime)
UPDATE d
	SET winlostdate = s.winlostdate
		,CustId = s.custid
		,Currency = s.currency
		,PartnerId = s.partnerid
		,Recommend = s.recommend
		,MRecommend = s.mrecommend
		,SRecommend = s.srecommend
		,TransferAmount = s.transferamount
OUTPUT inserted.custid, inserted.winlostdate INTO @updated_list		
FROM dbo.rptDepWinlost_Transfer3rdOthers d WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #TEMP s on d.custid = s.custid and d.winlostdate = s.winlostdate

DELETE D
FROM #TEMP D
	INNER JOIN @updated_list s on d.custid = s.custid and d.winlostdate = s.winlostdate

INSERT INTO dbo.rptDepWinlost_Transfer3rdOthers(winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount)
	SELECT winlostdate,CustId,Currency,PartnerId,Recommend,MRecommend,SRecommend,TransferAmount
	FROM #TEMP

DROP TABLE #TEMP

SET NOCOUNT OFF