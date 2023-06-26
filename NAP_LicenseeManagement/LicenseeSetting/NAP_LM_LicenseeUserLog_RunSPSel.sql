/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet,bodbLicenseeNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_LM_LicenseeUserLog_RunSPSel]    
    @CustId INT,
	@AgentID INT = 0,
    @FromDate DATETIME,
    @ToDate DATETIME,
    @ActionTypeId INT = 3,
    @IsInternal TINYINT,
    @LowerActionId INT = NULL,
	@UpperActionId INT = NULL,
    @PageIndex INT,
    @PageSize INT,
	@TotalItems INT OUTPUT
AS 
/*	Created:20230224@Winfred
    Task: ViewLog function NAP LM
    DB: DBLOG/bodb_CustomerLog
    
    Revisions:
		- 20230224@Winfred: NAP LM - Enhance Bet Setting function for AM to use [redmine:#178105]

	Description:
		- Get paged log run sp. If @LowerActionId and @UpperActionId are both not null, get actions in range 
	
    Param's Explaination:    
		- @UserId: a customer which we want to view actions affect to.
		- @AgentID: CustId or ALl AgentID
		- @FromDate: date range to view log
		- @ToDate: date range to view log
		- @ActionTypeId: action type. If ActionType < 0: select all type , 3 : bet limit
		- @IsInternal: accounting site = 1, agent = 0
		- @LowerActionId: query actionid in range
		- @UpperActionId: query actionid in range	
		- @PageIndex: from 0
		- @PageSize: total record per request
*/
BEGIN	
	SET NOCOUNT ON 
	
	SET @PageIndex = ABS(@PageIndex)
	SET @PageSize = ABS(@PageSize)  

	DECLARE @lbound INT 
			,@ubound INT
			,@roleid TINYINT
			,@LowerActionIdStatus INT
			,@UpperActionIdStatus INT
			,@i INT = 1000000

	DECLARE @tmpCust TABLE(Custid INT)		
	CREATE TABLE #tmpLog (LogID BIGINT,
						UserID INT,
						Username NVARCHAR(100),
						TrackingValue NVARCHAR(MAX),
						TrackingValueOld NVARCHAR(MAX),
						LogDate DATETIME,
						ActionID INT,
						ActionTypeID INT,
						SPName VARCHAR(50),
						IsInternal BIT,
						CustID INT,
						CustName NVARCHAR(100),
						ActionName NVARCHAR(512),
						RowNum INT IDENTITY(1,1)
					)
		
	INSERT INTO @tmpCust(Custid)	
	SELECT custid
	FROM bodb02.dbo.Customer WITH(NOLOCK)
	WHERE (@AgentID <> 0 AND custid = @AgentID) OR (@AgentID = 0 AND srecommend = @CustId  AND roleid = 2) 
			
	SET @lbound = @PageIndex * @PageSize       
		
	SET @ubound = @lbound + @PageSize 
	IF ( @PageIndex > 0 ) 
		SET @lbound = @lbound + 1

	DECLARE @__archiveDate DATETIME
	SELECT @__archiveDate = DATEADD(DAY, 1, dbo.f_CustomerLog_GetArchiveDate())

	IF @FromDate >= @__archiveDate
	BEGIN
		INSERT INTO #tmpLog(LogID,UserID,Username,TrackingValue,TrackingValueOld,LogDate,ActionID,ActionTypeID,SPName,IsInternal,CustID,CustName,ActionName)
		SELECT    LogID,
				UserID,
				Username =	CASE 
								when (c.RoleId > 4 and @IsInternal=0) THEN 'Admin'
								when (la.ActionID BETWEEN 2000 AND 3000 OR la.ActionID BETWEEN 1142 AND 1144 OR la.ActionID=1165) then 'Admin'
								ELSE c.Username
							END,
				CASE WHEN ul.ActionID IN  (1100,1101,1102,1103) AND ul.TrackingValue LIKE '%Hide*Cricket%' 
						THEN REPLACE(TrackingValue,'Hide*Cricket','HideCricket') 
						ELSE ul.TrackingValue END TrackingValue,
				TrackingValue2,
				LogDate,
				la.ActionID,
				ActionTypeID,
				la.SPName,
				IsInternal,
				ul.CustID,
				c.username AS CustName,
				la.ActionNameEN AS ActionName
		FROM      dbo.UserLog_RunSP AS ul WITH (NOLOCK)
				INNER JOIN dbo.LogAction AS la WITH (NOLOCK) ON ul.ActionID = la.ActionID
				LEFT JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON c.custid = ul.UserID					
		WHERE     ul.CustID IN (SELECT custid from @tmpCust)
				AND la.ActionTypeID = @ActionTypeId
				AND LogDate BETWEEN @FromDate AND @ToDate
				AND la.actionid BETWEEN @LowerActionId AND @UpperActionId
				AND IsInternal <= @IsInternal
				AND ISNULL(c.roleid,0) <= CASE WHEN @IsInternal = 1 THEN 999999 WHEN @IsInternal = 0 THEN 4 END
				AND (ul.ActionID <> 237 OR ul.TrackingValue IS NOT NULL)
		ORDER BY LogDate DESC
	END
	ELSE IF @ToDate < @__archiveDate
	BEGIN
		INSERT INTO #tmpLog(LogID,UserID,Username,TrackingValue,TrackingValueOld,LogDate,ActionID,ActionTypeID,SPName,IsInternal,CustID,CustName,ActionName)
		SELECT   LogID,
				UserID,
				Username =	CASE 
								when (c.RoleId > 4 and @IsInternal=0) THEN 'Admin'
								when (la.ActionID BETWEEN 2000 AND 3000 OR la.ActionID BETWEEN 1142 AND 1144 OR la.ActionID=1165) then 'Admin'
								ELSE c.Username
							END,
				CASE WHEN ul.ActionID IN  (1100,1101,1102,1103) AND ul.TrackingValue LIKE '%Hide*Cricket%' 
						THEN REPLACE(TrackingValue,'Hide*Cricket','HideCricket') 
						ELSE ul.TrackingValue END TrackingValue,
				TrackingValue2,
				LogDate,
				la.ActionID,
				ActionTypeID,
				la.SPName,
				IsInternal,
				ul.CustID,
				c.username AS CustName,
				la.ActionNameEN AS ActionName
		FROM      bodb_CustomerLog_Archive.dbo.UserLog_RunSP AS ul WITH (NOLOCK)
				INNER JOIN dbo.LogAction AS la WITH (NOLOCK) ON ul.ActionID = la.ActionID
				LEFT JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON c.custid = ul.UserID					
		WHERE      ul.CustID IN (SELECT custid from @tmpCust)
				AND la.ActionTypeID = @ActionTypeId
				AND LogDate BETWEEN @FromDate AND @ToDate
				AND la.actionid BETWEEN @LowerActionId AND @UpperActionId
				AND IsInternal <= @IsInternal
				AND ISNULL(c.roleid,0) <= CASE WHEN @IsInternal = 1 THEN 999999 WHEN @IsInternal = 0 THEN 4 END
				AND (ul.ActionID <> 237 OR ul.TrackingValue IS NOT NULL)
		ORDER BY LogDate DESC			
	END
	ELSE
	BEGIN
		INSERT INTO #tmpLog(LogID,UserID,Username,TrackingValue,TrackingValueOld,LogDate,ActionID,ActionTypeID,SPName,IsInternal,CustID,CustName,ActionName)
		SELECT  LogID,
				UserID,
				Username =	CASE 
								when (c.RoleId > 4 and @IsInternal=0) THEN 'Admin'
								when (la.ActionID BETWEEN 2000 AND 3000 OR la.ActionID BETWEEN 1142 AND 1144 OR la.ActionID=1165) then 'Admin'
								ELSE c.Username
							END,
				CASE WHEN ul.ActionID IN  (1100,1101,1102,1103) AND ul.TrackingValue LIKE '%Hide*Cricket%' 
						THEN REPLACE(TrackingValue,'Hide*Cricket','HideCricket') 
						ELSE ul.TrackingValue END TrackingValue,
				TrackingValue2,
				LogDate,
				la.ActionID,
				ActionTypeID,
				la.SPName,
				IsInternal,
				ul.CustID,
				c.username AS CustName,
				la.ActionNameEN AS ActionName
		FROM      dbo.UserLog_RunSP AS ul WITH (NOLOCK)
				INNER JOIN dbo.LogAction AS la WITH (NOLOCK) ON ul.ActionID = la.ActionID
				LEFT JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON c.custid = ul.UserID					
		WHERE      ul.CustID IN (SELECT custid from @tmpCust)
				AND la.ActionTypeID = @ActionTypeId
				AND LogDate BETWEEN @__archiveDate AND @ToDate
				AND la.actionid BETWEEN @LowerActionId AND @UpperActionId
				AND IsInternal <= @IsInternal
				AND ISNULL(c.roleid,0) <= CASE WHEN @IsInternal = 1 THEN 999999 WHEN @IsInternal = 0 THEN 4 END
				AND (ul.ActionID <> 237 OR ul.TrackingValue IS NOT NULL)
		ORDER BY LogDate DESC

		INSERT INTO #tmpLog(LogID,UserID,Username,TrackingValue,TrackingValueOld,LogDate,ActionID,ActionTypeID,SPName,IsInternal,CustID,CustName,ActionName)
		SELECT LogID,
				UserID,
				Username =	CASE 
								when (c.RoleId > 4 and @IsInternal=0) THEN 'Admin'
								when (la.ActionID BETWEEN 2000 AND 3000 OR la.ActionID BETWEEN 1142 AND 1144 OR la.ActionID=1165) then 'Admin'
								ELSE c.Username
							END,
				CASE WHEN ul.ActionID IN  (1100,1101,1102,1103) AND ul.TrackingValue LIKE '%Hide*Cricket%' 
						THEN REPLACE(TrackingValue,'Hide*Cricket','HideCricket') 
						ELSE ul.TrackingValue END TrackingValue,
				TrackingValue2,
				LogDate,
				la.ActionID,
				ActionTypeID,
				la.SPName,
				IsInternal,
				ul.CustID,
				c.username AS CustName,
				la.ActionNameEN AS ActionName
		FROM      bodb_CustomerLog_Archive.dbo.UserLog_RunSP AS ul WITH (NOLOCK)
				INNER JOIN dbo.LogAction AS la WITH (NOLOCK) ON ul.ActionID = la.ActionID
				LEFT JOIN bodb02.dbo.CustInfo AS c WITH(NOLOCK) ON c.custid = ul.UserID					
		WHERE     ul.CustID IN (SELECT custid from @tmpCust)
				AND la.ActionTypeID = @ActionTypeId
				AND LogDate >= @FromDate AND LogDate < @__archiveDate
				AND la.actionid BETWEEN @LowerActionId AND @UpperActionId
				AND IsInternal <= @IsInternal
				AND ISNULL(c.roleid,0) <= CASE WHEN @IsInternal = 1 THEN 999999 WHEN @IsInternal = 0 THEN 4 END
				AND (ul.ActionID <> 237 OR ul.TrackingValue IS NOT NULL)
		ORDER BY LogDate DESC
	END
	
	SELECT @TotalItems = MAX(RowNum) FROM #tmpLog c  

	SELECT  LogID,
			UserID,
			Username,
			TrackingValue,
			TrackingValueOld,
			LogDate,
			ActionID,
			ActionTypeID,
			SPName,
			IsInternal,
			CustID,
			CustName,
			ActionName
	FROM    #tmpLog
	WHERE   RowNum BETWEEN @lbound AND @ubound
	ORDER BY RowNum

	DROP TABLE #tmpLog
END
GO
