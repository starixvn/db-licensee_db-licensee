/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_ITUser_Select]
	@UserName VARCHAR(50) = '',
	@IsClosed BIT = 0,
	@PageIndex INT = 1,
	@PageSize INT = 20,
	@TotalItem INT = 0 OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2019-01-23
	 Task: Implement "IT User Management" function
	 DB: DBCUST.bodb_licensee
	 
	 Revisions:
	  - 20190123@Amanda: Select IT User [Redmine: #83584]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @tmpUserName VARCHAR(50)
	DECLARE @from INT, @to INT
	
	SET @from = ((@PageIndex - 1) * @PageSize) + 1
	SET @to = @from + @PageSize - 1	
	SET @tmpUserName = ISNULL('%' + @UserName + '%', '')

	;WITH User_CTE AS (
		SELECT	ROW_NUMBER() OVER (ORDER BY Username) AS RowId,
				UserID,
				Username,
				UserRole,
				FirstName,
				LastName,
				Email,
				[Status],
				Creator,
				CreateDate,
				LicenseeName,
				isInternal
		FROM dbo.Users WITH (NOLOCK)
		WHERE (@tmpUserName = '' OR Username LIKE @tmpUserName)
			AND ((@IsClosed = 0 AND [Status] = 'Open') OR (@IsClosed = 1 AND [Status] <> 'Open'))
			AND isInternal = 0
	)
	SELECT	UserID,
			Username,
			UserRole,
			FirstName,
			LastName,
			Email,
			[Status],
			Creator,
			CreateDate,
			LicenseeName,
			isInternal,
			CASE WHEN [Status] = 'Open' THEN 1 ELSE 0 END AS IsActive,
			CASE WHEN UserRole = 'Admin' THEN 1 ELSE 0 END AS IsAdmin
	FROM User_CTE
	WHERE RowId BETWEEN @from AND @to
	
	SELECT @TotalItem = COUNT(1)
	FROM dbo.Users WITH (NOLOCK)
	WHERE (@tmpUserName = '' OR Username LIKE @tmpUserName)
		AND ((@IsClosed = 0 AND [Status] = 'Open') OR (@IsClosed = 1 AND [Status] <> 'Open'))
		AND isInternal = 0
END
GO
