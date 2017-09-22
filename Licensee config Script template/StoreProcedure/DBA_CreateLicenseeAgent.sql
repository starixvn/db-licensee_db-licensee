USE bodb_licensee
GO

ALTER PROCEDURE [dbo].[DBA_CreateLicenseeAgent] 
	@LicenseeName		VARCHAR(50)
	, @SuperWildCard	VARCHAR(50)
	, @Currency			INT = 0
	, @IsSpecial		BIT = 0
	, @IsDeposit		INT = 1
AS
/*  
	 Created by: [20110127@Henry]  
	 Task: Create Licensee and the Agents for that Licensee  
	 DB: DB052.bodb_Licensee  
	 Param's Explanation:  
	 + @LicenseeName example: 12BET  
	 + @SuperWildCard example: 12BETSuper%  
	 + @Currency (default is 0: all currency) if <> 0 then will insert the agents for that currency only  
	 + @IsSpecial: if 1 then update column Description to normal, or affiliate or banner depend on:  
	 - username ending with 01: normal  
	 - username ending with 02: affiliate  
	 - username ending with 03: banner  
	 - username ending with 04: income access 
  
	 Revisions:  
		 - 20120509@Henry: add 1 more param: @IsDeposit (default = 1)  
		 - 20120611@Henry: only get from real agent (condition: username NOT like @LicenseeName + 'ACC%')  
		 - 20130603@Jim: restrict permission of Licensee User  
		 - 20170707@Harper: fix CurrencyUser when we still have this licensee and currency [RedmineID: #79235]
		 - 20170912@Harper: Clean code [RedmineID: #82673] 
*/
BEGIN
	DECLARE @LicenseeID INT
	DECLARE @agent AS TABLE ( LicenseeID INT
							, CustID INT
							, UserName VARCHAR(100)
							, RoleID INT
							, Currency INT
							, CurrencyName VARCHAR(100)
							, [Description] VARCHAR(100)
							)
	DECLARE @super AS TABLE (CustID INT)

	--insert new Licensee and get the ID  
	IF NOT EXISTS (
					SELECT 1
					FROM Licensees(NOLOCK)
					WHERE LicenseeName = @LicenseeName
				)
	BEGIN
		SELECT @LicenseeID = max(licenseeid) + 1
		FROM licensees WITH (NOLOCK)

		INSERT INTO Licensees ( LicenseeID, LicenseeName, IsDeposit	)
		VALUES ( @LicenseeID, @LicenseeName, @IsDeposit	)
	END
	ELSE
	BEGIN
		SELECT @LicenseeID = LicenseeID
		FROM Licensees(NOLOCK)
		WHERE LicenseeName = @LicenseeName
	END

	IF ISNULL(@LicenseeID, 0) = 0
		RAISERROR (	'Licensee could not found, please have a check!', 16, 1	)

	--get the superid  
	IF @Currency = 0
	BEGIN
		INSERT INTO @super (CustID)
		SELECT custid
		FROM bodb02.dbo.custinfo(NOLOCK)
		WHERE roleid = 4
			AND username LIKE @SuperWildCard
	END
	ELSE
	BEGIN
		INSERT INTO @super (CustID)
		SELECT custid
		FROM bodb02.dbo.custinfo(NOLOCK)
		WHERE roleid = 4
			AND username LIKE @SuperWildCard
			AND currency = @Currency
	END

	--get the licensee Agents  
	IF @LicenseeName = '12BET'
	BEGIN
		INSERT INTO @agent (LicenseeID, CustID, Username, RoleID, Currency, CurrencyName, [Description]	)
		SELECT @LicenseeID, custid, username, roleid, c.currency
			, CASE c.currency WHEN 20 THEN 'UUS' ELSE e.Code END AS currencyName
			, '' AS [description]
		FROM bodb02.dbo.custinfo c(NOLOCK)
		INNER JOIN bodb02.dbo.exchange e(NOLOCK) ON c.currency = e.exchangeid
		WHERE srecommend IN (
								SELECT custid
								FROM @super
							)
			AND roleid = 2
			AND username NOT LIKE '12BETAFF%'
			AND username NOT LIKE '12BETTAFF%'
			AND username NOT LIKE '12BETACC%'
	END
	ELSE
	BEGIN
		INSERT INTO @agent (LicenseeID, CustID, Username, RoleID, Currency, CurrencyName, [Description]	)
		SELECT @LicenseeID, custid, username, roleid, c.currency
			, CASE c.currency WHEN 20 THEN 'UUS' ELSE e.Code END AS currencyName
			, '' AS [description]
		FROM bodb02.dbo.custinfo c(NOLOCK)
		INNER JOIN bodb02.dbo.exchange e(NOLOCK) ON c.currency = e.exchangeid
		WHERE srecommend IN (
								SELECT custid
								FROM @super
							)
			AND roleid = 2
			AND username NOT LIKE @LicenseeName + 'ACC%'
	END

	--Update description  
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
		
		--04: income access
		UPDATE @agent
		SET [Description] = 'income access'
		WHERE substring(Username, len(Username) - 1, 2) = '04'
	END

	--insert licenseecust  
	INSERT INTO LicenseeCust (
		LicenseeID
		, CustID
		, RoleID
		, Currency
		, CurrencyName
		, [Description]
		)
	SELECT A.LicenseeID
		, A.CustID
		, A.RoleID
		, A.Currency
		, A.CurrencyName
		, A.[Description]
	FROM @agent A
	WHERE NOT EXISTS (
						SELECT *
						FROM licenseecust B(NOLOCK)
						WHERE A.LicenseeID = B.LicenseeID
							AND A.custid = B.custid
							AND A.roleid = B.roleid
							AND A.currency = B.currency
					)
	  
	-- Grant currency permission to Licensee's Users  
	
	DECLARE @tblCurrency	AS TABLE (	LicenseeID INT, CurrencyID INT )
	DECLARE @usr			AS TABLE ( LicenseeID INT, UserID INT)

	INSERT INTO @tblCurrency (LicenseeID, CurrencyID)
	SELECT DISTINCT LicenseeID, Currency 
	FROM dbo.LicenseeCust WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID

	INSERT INTO @usr (LicenseeID, UserID)
	SELECT DISTINCT LicenseeID, userID
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
		, u.LicenseeID
		, c.CurrencyID
		, 1
		, 1 ---- System=1 is default for LRF  
	FROM @usr u
		INNER JOIN @tblCurrency c ON u.LicenseeID = c.LicenseeID
	WHERE NOT EXISTS (
						SELECT 1 
						FROM dbo.CurrencyUser cur WITH (NOLOCK) 
						WHERE cur.SystemID = 1
							AND cur.usrID = u.UserID
							AND cur.LicenseeID = u.LicenseeID
							AND cur.CurrencyID = c.CurrencyID
						)
END
GO

GRANT EXECUTE ON [dbo].[DBA_CreateLicenseeAgent] TO [vnteam]
GO 
GRANT VIEW DEFINITION ON [dbo].[DBA_CreateLicenseeAgent] TO [vnteam]
GO 
