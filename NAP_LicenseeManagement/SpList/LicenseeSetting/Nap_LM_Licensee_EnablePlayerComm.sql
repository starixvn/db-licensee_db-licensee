/*<info serverAlias="DBCUST-bodb_Licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Nap_LM_Licensee_EnablePlayerComm] (@LicenseeName VARCHAR(500))
AS
/*  
	Created: Amanda
	Date: 2019-04-18 
	Task : re-structure create new licensee flow 
	DB: DBCUST.bodb_licensee  
	Original: DBA_Lrf_EnablePlayerComm
	   
	Revisions:  
	   - 20190418@Amanda: Move code from DBA_Lrf_EnablePlayerComm to this and refactor code [Redmine: #111321]
*/
BEGIN
	DECLARE @tblLicensee AS TABLE (
		[id] [int] IDENTITY(1, 1)
		, LicenseeID INT
		)
	DECLARE @tblFunctionComm AS TABLE (FunctionID INT)

	DECLARE @LicenseeID INT
		, @i INT
		, @maxID INT

	INSERT INTO @tblLicensee (LicenseeID)
	SELECT l.LicenseeID
	FROM dbo.Licensees l WITH (NOLOCK)
	WHERE l.licenseename IN (
			SELECT val AS LicenseeName
			FROM CUSTDB.dbo.strSplit(@LicenseeName, ',')
			)

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

	WHILE (@i < @maxID + 1)
	BEGIN
		SELECT @LicenseeID = LicenseeID
		FROM @tblLicensee
		WHERE ID = @i

		IF NOT EXISTS (
				SELECT 1
				FROM dbo.LicenseeCustComm(NOLOCK)
				WHERE LicenseeID = @LicenseeID
				)
		BEGIN
			--- initial data  
			INSERT INTO LicenseeCustComm (
				LicenseeID
				, CustID
				, SBComm
				, RacingComm
				, NGComm
				, GroupCommID
				, LCComm
				, RNGComm
				, Parlaycomm
				)
			SELECT t.LicenseeID
				, lci.CustID
				, 0 AS SBComm
				, 0 AS RacingComm
				, 0 AS NGComm
				, 0 AS GroupCommID
				, 0 AS LCComm
				, 0 AS RNGComm
				, 0 Parlaycomm
			FROM @tblLicensee t
			INNER JOIN dbo.LicenseeCust lc WITH (NOLOCK)
				ON t.LicenseeID = lc.LicenseeID
			INNER JOIN CUSTDB.dbo.Customer lci WITH (NOLOCK)
				ON lc.CustID = lci.recommend
			WHERE t.ID = @i
				AND lci.RoleID = 1
				AND NOT EXISTS (
					SELECT 1
					FROM LicenseeCustComm lcc WITH (NOLOCK)
					WHERE lcc.CustID = lci.CustID
					)

			--- grant comm function permission   
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