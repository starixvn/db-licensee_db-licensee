/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_DeactivateSystem]
	@LicenseeName	VARCHAR(50),
	@SystemName		VARCHAR(100)
AS
/*
	 Created: Amanda
	 Date: 2019-01-15
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 Original: DBA_Lrf_ActiveLicenseeSystem
	 
	 Revisions:
	  - 20190418@Amanda: Move code from DBA_Lrf_ActiveLicenseeSystem to this [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @Error NVARCHAR(MAX) = ''
	DECLARE @LicenseeId INT
	
	SELECT @LicenseeId = LicenseeId
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@SystemName,'') <> '' AND ISNULL(@LicenseeId, 0) <> 0
	BEGIN
		DECLARE @tblSystem AS TABLE (
				SystemId INT
				, SystemCode VARCHAR(10)
		)	

		INSERT INTO @tblSystem (SystemId, SystemCode)
		SELECT 0, val
		FROM CUSTDB.dbo.strSplit(@SystemName, ',')
		
		UPDATE a
		SET SystemId = b.id
		FROM @tblSystem a
		INNER JOIN dbo.Systems b WITH (NOLOCK)
		ON a.SystemCode = b.SystemName
		
		--- Set deactivate for all of existing systems  
		UPDATE sl
		SET sl.isActive = 0
		FROM dbo.SystemLicensee sl WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @tblSystem s ON sl.SystemID = s.SystemId
		WHERE sl.LicenseeID = @LicenseeId
	
		IF EXISTS (
			SELECT 1
			FROM dbo.SystemLicensee WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID
				AND IsActive = 0
				AND SystemID = 1 -- LRF
			)
		BEGIN
			EXEC DBPTCS.bodb_PlaytechCS.[dbo].[Nap_LM_PullServiceSetting]
						@LicenseeID = @LicenseeId, 
						@LicenseeName = @LicenseeName, 
						@SettingName = 'GoldDeluxe_VersionKey',
						@IsDelete = 1
			EXEC DBPTCS.bodb_PlaytechCS.[dbo].[Nap_LM_PullServiceSetting]
						@LicenseeID = @LicenseeId, 
						@LicenseeName = @LicenseeName, 
						@SettingName = 'AGCasino_VersionKey',
						@IsDelete = 1
		END
		
		IF EXISTS (SELECT 1 FROM @tblSystem WHERE SystemId = 0)
		BEGIN
			SELECT @Error = 'Invalid systems(s): ' + STUFF((
							SELECT ',' + SystemCode
							FROM @tblSystem
							WHERE SystemId = 0
						FOR XML PATH('')), 1, 1, '') 
		END
	END
	ELSE
	BEGIN
		SET @Error = 'Licensee is invalid or inactive system list is empty'
	END
	
	SELECT @Error AS Error
END
GO