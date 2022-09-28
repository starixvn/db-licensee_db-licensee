/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE	dbo.Acc_Dep_WLMonitored_Player_ReachDetail_Sel
	 @CustID INT
	,@Sporttype SMALLINT = 0
	,@FromDate DATETIME
	,@ToDate DATETIME
	,@SortType TINYINT = 1
	,@IsDesc BIT = 1
AS  
/*  
	Created:	20220523@Eden
	Task:		View Reached threshold history of specific member - Deposit
	DB:			DBEXT-bodb02 
	Original:	
  
	Revisions:  
	   - 20220523@Eden: LAP - Player Segmentation - Monitored Player [Redmine:#172605]

	Param's Explanation:  	
		- @SortType : ( order by)
			1: Date (default)
			2: Daily Winning Threshold
			3: Total Wining Amount

	EXEC Acc_Dep_WLMonitored_Player_ReachDetail_Sel 
		     @CustID	= 29047611	
			,@Sporttype = 0
			,@FromDate = '2022/05/01'
			,@ToDate = '2022/05/02'
			,@SortType = 3
			,@IsDesc = 0
	
*/  
BEGIN 
	SELECT ci.CustID
		, @Sporttype  AS Sporttype 
		, w.CreatedDate
		, ci.username
		, SUBSTRING(ci.username2,  CHARINDEX('$',ci.username2)+1, LEN(ci.username2)-CHARINDEX('$',ci.username2)) AS username2
		, e.ExchangeId
		, e.currency
		, w.WinningThreshold
		, w.AccumWL AS WinLossAmount	
	FROM Dep_WLMonitored_Player_History w WITH(NOLOCK)
		INNER JOIN customer ci WITH(NOLOCK) ON ci.custid = w.custid
		INNER JOIN Exchange e WITH(NOLOCK) ON e.ExchangeId = ci.currency
	WHERE w.CustID = @CustID
		AND sporttype = @Sporttype
		AND ci.roleid = 1
		AND w.CreatedDate >= @FromDate
		AND w.CreatedDate < @ToDate + 1
	ORDER BY	CASE WHEN @SortType = 1 AND @IsDesc = 0 THEN w.CreatedDate END ASC,
				CASE WHEN @SortType = 2 AND @IsDesc = 0 THEN w.WinningThreshold END ASC,
				CASE WHEN @SortType = 3 AND @IsDesc = 0 THEN w.AccumWL END ASC,
				-----------
				CASE WHEN @SortType = 1 AND @IsDesc = 1 THEN w.CreatedDate END DESC,
				CASE WHEN @SortType = 2 AND @IsDesc = 1 THEN w.WinningThreshold END DESC,
				CASE WHEN @SortType = 3 AND @IsDesc = 1 THEN w.AccumWL END DESC,
				w.CreatedDate DESC
END
GO
