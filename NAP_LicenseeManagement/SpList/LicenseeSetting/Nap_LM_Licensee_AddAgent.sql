/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_AddAgent]
	@LicenseeName		VARCHAR(50)
	, @SuperWildCard	VARCHAR(50)
	, @Currency			INT = 0
	, @IsSpecial		BIT = 0
	, @AffectedRows		INT = 0 OUTPUT
	, @ErrMsg			NVARCHAR(200) = ''	OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2018-11-20
	 Task: Create Licensee and the Agents for that Licensee
	 DB: DBCUST.bodb_licensee
	 Original: DBA_CreateLicenseeAgent
	 
	 Revisions:
	  - 20181120@Amanda: Add Agent/Currency of Licensee [Redmine: #83584]
	  - 20190418@Amanda: Move code from DBA_CreateLicenseeAgent to this [Redmine: #111321]
	  - 20190506@Amanda: Add Company Win Limit setting [Redmine: #112684]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @LicenseeId INT
	
	SELECT @LicenseeId = LicenseeID
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	IF(ISNULL(@LicenseeID, 0) = 0)
	BEGIN
		SET @AffectedRows = 0
		RETURN
	END
	
	DECLARE @super AS TABLE (CustID INT, CurrencyId INT)
	DECLARE @agent AS TABLE (
						CustID			INT
					,	UserName		VARCHAR(100)
					,	RoleID			INT
					,	Currency		INT
					,	CurrencyName	VARCHAR(100)
					,	[Description]	VARCHAR(100)
					)
	DECLARE @SuperWildCardText VARCHAR(50)
	DECLARE @SumCust1 INT, @SumCust2 INT
	DECLARE @AddCWLSetting BIT

	SET @SuperWildCardText = @SuperWildCard + '%'
	SELECT @SumCust1 = COUNT(1) FROM dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND RoleID = 2

	-- GET SUPER ID
	IF @Currency = 0
	BEGIN
		INSERT INTO @super (CustID, CurrencyId)
		SELECT custid, currency
		FROM CUSTDB.dbo.custinfo WITH (NOLOCK)
		WHERE roleid = 4 AND username LIKE @SuperWildCardText
	END
	ELSE
	BEGIN
		INSERT INTO @super (CustID, CurrencyId)
		SELECT custid, currency
		FROM CUSTDB.dbo.custinfo WITH (NOLOCK)
		WHERE roleid = 4 AND username LIKE @SuperWildCardText AND currency = @Currency
	END
	
	IF EXISTS (SELECT 1 FROM @super c WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.LicenseeCust lc WHERE lc.LicenseeID = @LicenseeId AND lc.Currency = c.CurrencyId))
	BEGIN
		SET @AddCWLSetting = 1
	END
	
	-- GET LICENSEE AGENTs  
	IF @LicenseeName = '12BET'
	BEGIN
		INSERT INTO @agent (
			CustID
			, Username
			, RoleID
			, Currency
			, CurrencyName
			, [Description]
		)
		SELECT c.custid
			, c.username
			, c.roleid
			, c.currency
			, CASE c.currency WHEN 20 THEN 'UUS' ELSE e.Code END AS currencyName
			, '' AS [description]
		FROM CUSTDB.dbo.custinfo c WITH (NOLOCK)
		INNER JOIN CUSTDB.dbo.exchange e WITH (NOLOCK) ON c.currency = e.exchangeid
		WHERE EXISTS (SELECT 1 FROM @super s WHERE s.CustID = c.srecommend)
			AND c.roleid = 2
			AND c.username NOT LIKE '12BETAFF%'
			AND c.username NOT LIKE '12BETTAFF%'
			AND c.username NOT LIKE '12BETACC%'
	END
	ELSE
	BEGIN
		INSERT INTO @agent (
			CustID
			, Username
			, RoleID
			, Currency
			, CurrencyName
			, [Description]
			)
		SELECT c.custid
			, c.username
			, c.roleid
			, c.currency
			, CASE c.currency WHEN 20 THEN 'UUS' ELSE e.Code END AS currencyName
			, '' AS [description]
		FROM CUSTDB.dbo.custinfo c WITH (NOLOCK)
		INNER JOIN CUSTDB.dbo.exchange e WITH (NOLOCK)
			ON c.currency = e.exchangeid
		WHERE EXISTS (SELECT 1 FROM @super s WHERE s.CustID = c.srecommend)
			AND c.roleid = 2
			AND c.username NOT LIKE @LicenseeName + 'ACC%'
	END

	-- UPDATE DESCRIPTION  
	IF @IsSpecial = 1
	BEGIN
		--01: normal  
		UPDATE @agent
		SET [Description] = 'normal'
		WHERE substring(Username, len(Username) - 1, 2) = '01'

		--02: affiliate  
		UPDATE @agent
		SET [Description] = 'affiliate'
		WHERE substring(Username, len(Username) - 1, 2) = '02'

		--03: banner  
		UPDATE @agent
		SET [Description] = 'banner'
		WHERE substring(Username, len(Username) - 1, 2) = '03'

		UPDATE @agent
		SET [Description] = 'income access'
		WHERE substring(Username, len(Username) - 1, 2) = '04'
	END
	
	-- INSERT LICENSEE CUST  
	INSERT INTO LicenseeCust (
		LicenseeID
		, CustID
		, RoleID
		, Currency
		, CurrencyName
		, [Description]
	)
	SELECT @LicenseeId
		, a.CustID
		, a.RoleID
		, a.Currency
		, a.CurrencyName
		, a.[Description]
	FROM @agent a
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.LicenseeCust b WITH (NOLOCK)
			WHERE b.LicenseeID = @LicenseeId
				AND a.custid = b.custid
				AND a.roleid = b.roleid
				AND a.currency = b.currency
	)
	
	-- GRANT CURRENCY PERMISSION TO LICENSEE's USERs
	DECLARE @tblCurrency AS TABLE (CurrencyID INT)

	DECLARE @usr AS TABLE (UserID INT)

	INSERT INTO @tblCurrency (CurrencyID)
	SELECT DISTINCT Currency AS CurrencyID
	FROM dbo.LicenseeCust WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	INSERT INTO @usr (UserID)
	SELECT userID
	FROM dbo.LicenseeUser WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	INSERT INTO dbo.CurrencyUser (
		usrID
		, LicenseeID
		, CurrencyID
		, SystemID
		, isActive
		)
	SELECT userID
		, @LicenseeId
		, c.CurrencyID
		, 1 ---- System=1 is default for LRF
		, 1
	FROM @usr u
	CROSS JOIN @tblCurrency c
	WHERE NOT EXISTS (SELECT 1 
					FROM dbo.CurrencyUser cur WITH (NOLOCK) 
					WHERE cur.SystemID = 1
						AND cur.usrID = u.UserID
						AND cur.LicenseeID = @LicenseeId
						AND cur.CurrencyID = c.CurrencyID)
	
	-- RETURN RESULT
	SELECT @SumCust2 = COUNT(1) FROM dbo.LicenseeCust WITH (NOLOCK) WHERE LicenseeID = @LicenseeID AND RoleID = 2
	
	SET @AffectedRows = @SumCust2 - @SumCust1
	
	IF @AddCWLSetting = 1 AND @AffectedRows > 0
	BEGIN
		EXEC CustDB.dbo.Dot_Dep_CWL_InsertSetting @LicenseeID = @LicenseeId, @ErrMsg = @ErrMsg OUTPUT
	END
END
GO