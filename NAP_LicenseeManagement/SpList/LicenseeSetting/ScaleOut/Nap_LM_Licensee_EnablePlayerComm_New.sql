/*<info serverAlias="DBCUST-bodb_Licensee" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_LM_Licensee_EnablePlayerComm_New] 
	@LicenseeName VARCHAR(500)
AS
/*
	Created: 20240705@Eden  
	Task : SiteBuider --> Create new licensee setting on Licensee DB
	DB: DBCUST-bodb_Licensee
	Original sp: Nap_LM_Licensee_EnablePlayerComm
	
	Revisions: 
		- 20240705@Eden  : Scale out DBCUST - Licensee Customer in GlobCustDB [redmine: #207474]
		- 20241010@Johnson: HF- restructure LAP Comm [redmine:#212004]
	Param's Explanation: 
		Sample Format:
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @tblLicensee AS TABLE ([id] [int] IDENTITY(1, 1), LicenseeID INT)
	DECLARE @tblFunctionComm AS TABLE (FunctionID INT)

	DECLARE @LicenseeID INT
		, @i INT
		, @maxID INT

	INSERT INTO @tblLicensee (LicenseeID)
	SELECT l.LicenseeID
	FROM dbo.Licensees l WITH (NOLOCK)
	WHERE l.licenseename IN (SELECT value AS LicenseeName FROM STRING_SPLIT(@LicenseeName, ','))

	UPDATE dbo.Licensees WITH (ROWLOCK, UPDLOCK)
	SET IsAllowedMemberComm = 1
	FROM dbo.Licensees l
		INNER JOIN @tblLicensee t ON t.licenseeID = l.licenseeID

	INSERT INTO @tblFunctionComm (FunctionId)
	SELECT FunctionId
	FROM dbo.Functions WITH (NOLOCK)
	WHERE ParentId = 4 OR FunctionId = 4 -- CUSTOMER INFORMATION

	SELECT @i = 1
		, @maxID = MAX(ID)
	FROM @tblLicensee

	WHILE @i < @maxID + 1
	BEGIN
		SELECT @LicenseeID = LicenseeID
		FROM @tblLicensee
		WHERE ID = @i

		IF NOT EXISTS (SELECT 1 FROM dbo.LicenseeCustDiscount(NOLOCK) WHERE LicenseeID = @LicenseeID)
		BEGIN
			-- initial data
			INSERT INTO LicenseeCustDiscount (
				LicenseeID
				, CustID				
				, GroupDiscountID				
				)
			SELECT t.LicenseeID
				, lci.CustID			
				, 0 AS GroupDiscountID			
			FROM @tblLicensee t
				INNER JOIN dbo.LicenseeCust lc WITH (NOLOCK) ON t.LicenseeID = lc.LicenseeID
				INNER JOIN GlobCustDB.dbo.custinfomini lci WITH (NOLOCK) ON lc.CustID = lci.recommend
			WHERE t.ID = @i
				AND lci.RoleID = 1
				AND NOT EXISTS (
					SELECT 1
					FROM LicenseeCustComm lcc WITH (NOLOCK)
					WHERE lcc.CustID = lci.CustID
					)

			-- grant comm function permission
			INSERT INTO dbo.LicenseeFunctions (
				LicenseeId
				, FunctionId
				)
			SELECT @licenseeid
				, f.FunctionID
			FROM @tblFunctioncomm f
			WHERE NOT EXISTS (
					SELECT 1
					FROM dbo.LicenseeFunctions lf WITH (NOLOCK)
					WHERE lf.LicenseeId = @licenseeid AND lf.FunctionId = f.FunctionID
					)

			INSERT INTO [dbo].[LicenseeUserFunctions] (
					userid
					, functionid
					, licenseeid
					)
			SELECT lu.userid
				, f.FunctionID
				, @LicenseeID
			FROM dbo.LicenseeUser lu WITH (NOLOCK)
				INNER JOIN dbo.Users u WITH (NOLOCK) ON lu.UserID = u.UserID
				CROSS JOIN @tblFunctioncomm f
			WHERE lu.isactive = 1
				AND lu.licenseeid = @licenseeid
				AND u.[Status] = 'Open'
				AND NOT EXISTS (
						SELECT 1
						FROM dbo.LicenseeUserFunctions luf WITH (NOLOCK)
						WHERE luf.LicenseeId = @LicenseeID
							AND luf.UserId = lu.UserID
							AND luf.FunctionId = f.FunctionID
					)
		END

		SET @i = @i + 1
	END
END
GO
