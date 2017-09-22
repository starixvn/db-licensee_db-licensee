/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[DBA_Lrf_ActiveLicenseeSystem] (
	@LicenseeName VARCHAR(50)
	, @SystemisActive VARCHAR(100) = ''
	, @SystemDeactivate VARCHAR(100) = ''
	, @ErrCode INT = 0 OUTPUT
	, @ErrMsg NVARCHAR(1000) = '' OUTPUT
	)
/*  
	Created: 20140502@Jim  
	Task : re-structure create new licensee flow  
	DB: DBLIC.bodb_licensee  
		 
	Revisions:  
		- 20160912@Jim: add pull service into this flow
		- 20170912@Harper: Clear code [RedmineID: #82673] 
   
	Param's Explanation:  
   
*/
AS
BEGIN

	DECLARE @tblSystem	AS TABLE ( ID INT IDENTITY(1, 1)
								, SystemId INT
								, SystemCode VARCHAR(10)
								, isActive BIT
								)
	DECLARE @LicenseeId INT

	---   init variable   
	SELECT @LicenseeId = LicenseeId
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName	

	IF ISNULL(@SystemisActive, '') <> ''
	BEGIN
		INSERT INTO @tblSystem (SystemId, SystemCode, isActive)		
		SELECT 0, val, 1
		FROM bodb02.dbo.strSplit(@SystemisActive, ',')
	END	

	IF ISNULL(@SystemDeactivate, '') <> ''
	BEGIN
		IF @SystemDeactivate = 'All'
		BEGIN
			INSERT INTO @tblSystem (SystemId, SystemCode, isActive)
			SELECT DISTINCT ls.SystemID, s.SystemName, 0
			FROM dbo.SystemLicensee ls WITH (NOLOCK)
				INNER JOIN dbo.Systems s WITH (NOLOCK) ON ls.SystemID = s.id
			WHERE ls.IsActive = 1 AND ls.LicenseeID = @LicenseeId
		END
		ELSE
		BEGIN
			INSERT INTO @tblSystem (SystemId, SystemCode, isActive)
			SELECT 0, val, 0
			FROM bodb02.dbo.strSplit(@SystemDeactivate, ',')
		END
	END

	----- Correct Data   
	UPDATE a
	SET SystemId = b.id
	FROM @tblSystem a
		INNER JOIN dbo.Systems b WITH (NOLOCK) ON a.SystemCode = b.SystemName

	IF NOT EXISTS (	SELECT TOP 1 1	FROM @tblSystem	WHERE SystemId <> 0	)
	BEGIN
		SELECT @ErrCode = 101
			, @ErrMsg = 'SystemID is  not correct, please check again'

		RETURN
	END

	--- Set active/deactivate for all of existing systems  
	UPDATE a1
	SET isActive = b1.isActive
	FROM dbo.SystemLicensee a1
		INNER JOIN @tblSystem b1 ON a1.SystemID = b1.SystemId
	WHERE a1.LicenseeID = @LicenseeId

	DELETE @tblSystem
	WHERE SystemId IN (
						SELECT SystemId
						FROM dbo.SystemLicensee WITH (NOLOCK)
						WHERE LicenseeID = @LicenseeId
						)

	--- Set active/deactivate for all of new systems  
	MERGE dbo.SystemLicensee AS TARGET
	USING (
			SELECT SystemId, @LicenseeId AS LicenseeId, isActive
			FROM @tblSystem
		) AS SOURCE(SystemId, LicenseeId, isActive)
		ON (
				TARGET.SystemId = SOURCE.SystemId
				AND TARGET.LicenseeId = SOURCE.LicenseeId
				AND TARGET.IsActive = SOURCE.IsActive
			)
	WHEN MATCHED
		THEN
			UPDATE
			SET TARGET.isActive = SOURCE.isActive
	WHEN NOT MATCHED
		THEN
			INSERT ( SystemId, LicenseeId, isActive	)
			VALUES (
				SOURCE.SystemId
				, SOURCE.LicenseeId
				, SOURCE.isActive
				);

	--- deactive pull service 
	IF EXISTS (
				SELECT TOP 1 1
				FROM dbo.SystemLicensee WITH (NOLOCK)
				WHERE LicenseeID = @LicenseeID
					AND IsActive = 0
					AND SystemID = 1
			)
	BEGIN
		DELETE [bodb_PlaytechCS].[dbo].[LicIntegrationSetting]
		WHERE LicenseeName = @LicenseeName
			--AND SettingName  IN ('GoldDeluxe_VersionKey','AGCasino_VersionKey')
	END
END
GO
