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
	
*/
SET NOCOUNT ON


SELECT  currencyID,LicenseeID into #currency
FROM  dbo.Lrf_f_GetCurrencybyUser(@licenseeID,@userID,1)-- System is default=1 (LRF)
WHERE (@CurrencyID=0  OR (@CurrencyID<>0 AND CurrencyID=@CurrencyID))

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
    SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust lc  WITH ( NOLOCK )  
						INNER JOIN #Currency c ON lc.LicenseeID=c.LicenseeID AND lc.Currency=c.CurrencyID
                WHERE    [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 
DROP TABLE #Currency
DECLARE @bc TABLE (custid INT, betcount INT)
INSERT INTO @bc (custid, betcount)
SELECT  b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT matchid,eventdate FROM match WITH (nolock) WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.matchid = m.matchid
WHERE 
	b.recommend IN (SELECT custid FROM @TempAg) 
	AND b.statusID IN (101, 102)
GROUP BY b.custid

INSERT INTO @bc (custid, betcount)
SELECT b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT orid,eventdate FROM outright WITH (nolock) WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.matchid = m.orid
WHERE 
	b.recommend IN (SELECT custid FROM @TempAg) 
	AND b.statusID IN (101, 102)
GROUP BY b.custid

INSERT INTO @bc (custid, betcount)
SELECT b.custid, SUM(1) AS betcount
FROM 
	bettrans AS b WITH (nolock)
	INNER JOIN (SELECT orid,eventdate FROM dbo.VSOutright WITH (nolock) WHERE eventdate > DATEADD(day,-3,CURRENT_TIMESTAMP))  AS m ON b.matchid = m.orid
WHERE 
	b.recommend IN (SELECT custid FROM @TempAg) 
	AND b.statusID IN (101, 102)
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

