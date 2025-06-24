/*<info serverAlias="DBPLO-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Lrf_Rpt_Audit_AdminPlayerSearch]  	
	@SearchName		VARCHAR(50)
AS 
/*  
	Created: 20231025@Bobby
    Description: LAP - Implement new report for auditing
    DB: DBPLO.bodb02
   
    Revisions:  
		- 20231025@Bobby: Customer Admin - [redmine: #195850]
		- 20240321@Eddie: Change Link Server and metadata "bodbLicenseeNet" [RedmineID: #202712]
		- 20250620@Kelvin: Handle Security (Dynamic Query) issue [RedmineID: #227496]
		
    Param's Explanation:  
	  
*/
BEGIN  
    
	SET NOCOUNT ON;
    DECLARE @SiteName VARCHAR(15) = '12Bet';
	
	DROP TABLE IF EXISTS #tmpPlayerInfo;
	CREATE TABLE #tmpPlayerInfo (
        Currency VARCHAR(10)
		,IP	VARCHAR(45)
		,[Date of Registration] DATETIME
		,[First name] NVARCHAR(100)
		,[Last name] NVARCHAR(100)
		,[Preferred user name] NVARCHAR(100)
		,Gender NVARCHAR(100)
		,Email	NVARCHAR(100)
		,Mobile NVARCHAR(100)
		,Active	NVARCHAR(10)
		,Locked	NVARCHAR(10)
		,[Security question] NVARCHAR(250)
		,[Security code] NVARCHAR(100)
		,Country NVARCHAR(100)
        ,IBCCustID INT
    );

	--EXEC usp_Dep_Customer_List_xtest
	DECLARE @rmtQuery NVARCHAR(MAX), @spName VARCHAR(100) = 'usp_Dep_Customer_List', @IsTest BIT

	SET @IsTest = [dbo].[f_CheckSPVersion](@@PROCID);

	SELECT @spName += IIF(@IsTest = 1, '_xtest', ''),
	@rmtQuery = N'
	INSERT INTO #tmpPlayerInfo
	EXEC DBDEPOSIT2.Deposit_DB.dbo.' + @spName + ' @Username = @SearchName'

	EXEC sp_executesql @rmtQuery, N'@SearchName VARCHAR(50)', @SearchName

	SELECT TOP (1) pp.[CustID]
        ,@SearchName AS [UserName] 
        ,d.Currency AS [CurrencyCode]
        ,d.[Date of Registration] AS [RegisteredDate]
        ,d.[IP]
        ,d.[Country]
        -------------Player infomation
        ,d.[First name] AS [FirstName]
        ,d.[Last name] AS [LastName]
        ,d.[Gender]
        ,d.[Preferred user name] AS [PreferredUserName]
        ,d.[Email]
        ,d.[Mobile]
        ,d.[Active]
        ,d.[Locked]
        ,d.[Security question] AS [SecurityQuestion]
        ,d.[Security code] AS [SecurityCode]
    FROM #tmpPlayerInfo d
	INNER JOIN bodb_Ploutos.dbo.PlayerProfile pp WITH(NOLOCK) ON pp.CustID = d.IBCCustID
	WHERE pp.BrandCode = @SiteName
    ;
END
GO