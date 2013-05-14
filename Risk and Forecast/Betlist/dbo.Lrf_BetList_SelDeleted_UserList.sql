ALTER PROCEDURE [dbo].[Lrf_BetList_SelDeleted_UserList]
@LicenseeID INT,
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
	
*/
SET NOCOUNT ON

DECLARE @TempAg AS TABLE (custid INT)
INSERT INTO @TempAg (custid)
    SELECT  CustID  
                FROM    bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )  
                WHERE   LicenseeID = @LicenseeID  
                        AND  (@CurrencyID=0 OR (@CurrencyID <> 0 AND  Currency = @CurrencyID))
                        AND [Description] = COALESCE(@LicenseeType,  
                                                     [Description]) 

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

