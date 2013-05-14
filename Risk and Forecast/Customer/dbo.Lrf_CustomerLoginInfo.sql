ALTER  PROCEDURE [dbo].[Lrf_CustomerLoginInfo]
	@LicenseeID INT,
	@CustID INT
AS

/*
	Created by: [20110624@Henry]
	Task: Get Login Info
	DB: DB052.BODB02 
	Original: 
	Revisions:
		- 20120203@Henry: get SpecialLevelUpdateBy and SpecialLevelUpdateDate
		- 20120718@Henry: fix bug display wrong TnxDate
	
	Param's Explanation:
	
	
*/

SET NOCOUNT ON

DECLARE @Temp AS TABLE(
	LicenseeID INT,
	CustID INT,
	LastUpdateBA SMALLDATETIME,
	BAUpdatedBy VARCHAR (50)
)
DECLARE @LastTransferDate DATETIME
DECLARE @SpecialLevelUpdateByName VARCHAR(50), @SpecialLevelUpdateDate DATETIME,@SpecialLevelUpdateByID INT



SELECT TOP 1 @SpecialLevelUpdateByID=UserID, @SpecialLevelUpdateDate=LogDate
	FROM bodb_CustomerLog.dbo.UserLog_RunSP WITH (NOLOCK)
	WHERE 
		CustID = @CustID
		AND ActionID = 2407
	ORDER BY LogDate DESC
	
	IF ISNULL(@SpecialLevelUpdateByID,0) <> 0
	BEGIN
		SELECT @SpecialLevelUpdateByName = Username FROM bodb_Licensee.dbo.Users WITH (NOLOCK)
		WHERE UserID = @SpecialLevelUpdateByID
	END


--Running
INSERT INTO @Temp (LicenseeID, CustID, LastUpdateBA, BAUpdatedBy)
SELECT TOP 1 LicenseeID, lb.CustID, OnDate AS LastUpdateBA, u.Username AS BAUpdatedBy 
FROM 
	bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock) 
	INNER JOIN bodb_Licensee.dbo.Users u with (nolock) ON lb.OnBy = u.userid
WHERE 
	LicenseeID = @LicenseeID
	AND lb.CustID = @CustID
	AND lb.Status = 'Running'
ORDER BY OnDate DESC	
	
IF (SELECT COUNT(*) FROM @Temp) = 0
BEGIN
	--Done
	INSERT INTO @Temp (LicenseeID, CustID, LastUpdateBA, BAUpdatedBy)
	SELECT TOP 1 LicenseeID, lb.CustID, OffDate AS LastUpdateBA, u.Username AS BAUpdatedBy 
	FROM 
		bodb_Licensee.dbo.LicenseeBAHistory lb WITH (nolock) 
		INNER JOIN bodb_Licensee.dbo.Users u with (nolock) ON lb.OffBy = u.userid
	WHERE 
		LicenseeID = @LicenseeID
		AND lb.CustID = @CustID
		AND lb.Status = 'Done'
	ORDER BY OffDate DESC
END	

SELECT @LastTransferDate = MAX(transdate) FROM bettrans WITH (NOLOCK)
WHERE 
	custid = @CustID
	AND bettype <= 999
	
IF 	ISNULL(@LastTransferDate,'') = ''
BEGIN
	SELECT @LastTransferDate = MAX(transdate) FROM bettrans14 WITH (NOLOCK)
	WHERE custid = @CustID
END

IF 	ISNULL(@LastTransferDate,'') = ''
BEGIN
	SELECT @LastTransferDate = MAX(transdate) FROM DB06.bodb_archive.dbo.bettrans_bk WITH (NOLOCK)
	WHERE custid = @CustID
END

IF ISNULL(@LastTransferDate,'') = ''
BEGIN
	SELECT @LastTransferDate = MAX(transdate) FROM bettrans WITH (NOLOCK)
	WHERE custid = @CustID
END


SELECT 
	c.custid, 
	c.username, 
	SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS nickname,
	c.lastlogged, 
	c.creatdate AS createdate,  
	@LastTransferDate AS LastTransferDate,
	CASE WHEN t.CustID IS NULL THEN NULL ELSE t.LastUpdateBA END AS LastUpdateBA, 
	CASE WHEN t.CustID IS NULL THEN NULL ELSE t.BAUpdatedBy END AS BAUpdatedBy,
	@SpecialLevelUpdateByName AS SpecialLevelUpdateBy,
	@SpecialLevelUpdateDate AS SpecialLevelUpdateDate
FROM
	Customer c WITH(NOLOCK) 
	LEFT JOIN @Temp t ON c.CustID = t.CustID
WHERE 
	c.CustID = @CustID
	


GO
GRANT EXECUTE ON [dbo].[Lrf_CustomerLoginInfo] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_CustomerLoginInfo] TO [vnteam]

