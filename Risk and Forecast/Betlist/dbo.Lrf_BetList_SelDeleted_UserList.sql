USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelDeleted_UserList]    Script Date: 4/8/2014 4:41:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted_UserList] 
@LicenseeID INT,
@UserID	INT,
@CurrencyID INT=0,
@LicenseeType VARCHAR(100) = NULL
AS
/*
	Created by: Henry@20101210
	DB: DB052.BODB02
	Original: [Age_BetList_SelDeleted_UserList_Ag]
	 
	Revisions:
		 - 20110302@Henry: Allow to choose all type of licensee AND all currency 
		 - 20110325@Henry: support username2 to the list
		 - 20121004@Jim: replace @currencyname input param by @currencyID
		 - 20130514@Jim: Restrict permission of Licensee Users by currency
		 - 20130809@Jim: offer Virtual Horse Racing
		 - 20140403@Hannah: offer Keno
		 - 20140408@Florent: add more condition for keno
		 - 20141111@Jim: use  f_SelLicenseeCust instead of licenseecust (#Redmine 25673)
		 - 20150409@Winnie: Apply spottype bettype matrix 
*/ 
SET NOCOUNT ON

SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

------------
DECLARE @SportBettype TABLE(ProductID INT,Bettype INT,EventType INT)
INSERT INTO @SportBettype
EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode=4
------------

DECLARE @TempAg AS TABLE (custid INT,Currency INT)
INSERT INTO @TempAg (custid,Currency)
SELECT  CustID 
		,Currency
FROM    bodb_Licensee.dbo.f_SelLicenseeCust(@licenseeID) lc
		INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
WHERE    [Description] = COALESCE(@LicenseeType,  
									 [Description]) 
									 
DROP TABLE #Currency
DECLARE @bc TABLE (custid INT, betcount INT)
INSERT INTO @bc (custid, betcount)
SELECT  b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT matchid,eventdate 
				FROM match WITH (nolock) 
				WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.matchid = m.matchid
	INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
	INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype		
WHERE 
	b.statusID IN (101, 102)
	AND ((sbt.ProductID!=2 AND sbt.ProductID!=1 AND sbt.ProductID!=5) OR (sbt.ProductID=1 AND sbt.EventType!=2) OR (sbt.ProductID=5 AND sbt.EventType!=3))
	--and b.bettype not in (10,31,32,33,41,42,43,1231,1232,1233,1237,1238) --20140408@Florent: exclude outright, HR from sportbook
	--and b.bettype not between 1501 and 1599 -- exclude Keno from sportbook
GROUP BY b.custid

INSERT INTO @bc (custid, betcount)
SELECT b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT orid,eventdate 
				FROM outright WITH (nolock)	
				WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.matchid = m.orid
	INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency	
	INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype			
WHERE 
	--b.bettype in (10,31,32,33,41,42,43)
	sbt.ProductID=2 OR (sbt.ProductID=1 AND sbt.EventType=2)
	AND b.statusID IN (101, 102)
GROUP BY b.custid

INSERT INTO @bc (custid, betcount)
SELECT b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT orid,eventdate 
				FROM dbo.VSOutright WITH (nolock) 
				WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.oddsid = m.orid
	INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency		
	INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype			
WHERE 
	--b.bettype in (1231, 1232, 1233, 1237, 1238)
	sbt.ProductID=5 AND sbt.EventType=3
	AND b.statusID IN (101, 102)
GROUP BY b.custid

-- Keno
INSERT INTO @bc (custid, betcount)
SELECT  b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN 	@TempAg ag ON b.recommend = ag.CustId AND b.Currency = ag.Currency
	INNER JOIN @SportBettype sbt ON sbt.Bettype=b.bettype
WHERE 
	b.statusID IN (101, 102)
	AND b.winlostdate > DATEADD(day,-3,CURRENT_TIMESTAMP)
	AND sbt.ProductID=8
	--AND b.bettype BETWEEN 1501 AND 1599
	--AND b.ruben = 1
GROUP BY b.custid

SELECT 
c.username, 
c.custid, 
SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, len(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
SUM(betcount) AS betcount
FROM
	customer AS c WITH (nolock) 
	INNER JOIN @bc AS b ON c.custid = b.custid
WHERE c.roleid = 1
GROUP BY c.username, c.custid, c.username2
GO

GRANT EXECUTE ON [dbo].[Lrf_BetList_SelDeleted_UserList] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelDeleted_UserList] TO [vnteam]