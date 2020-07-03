/*<info serverAlias="DBCUST-bodb_licensee" executers="bodbLicenseeNet,Dot_Member" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Nap_LM_Licensee_ActivateSystem]
	@LicenseeName	VARCHAR(50),
	@SystemName		VARCHAR(100),
	@ErrMsg			NVARCHAR(200) = '' OUTPUT
AS
/*
	 Created: Amanda
	 Date: 2019-01-15
	 Task: Implement "Licensee Setting" function
	 DB: DBCUST.bodb_licensee
	 Original: DBA_Lrf_ActiveLicenseeSystem
	 
	 Revisions:
	  - 20190115@Amanda: Activate Systems for Licensee [Redmine: #83584]
	  - 20190418@Amanda: Move code from DBA_Lrf_ActiveLicenseeSystem to this [Redmine: #111321]
*/
BEGIN
	SET NOCOUNT ON;
	DECLARE @LicenseeId INT
	
	SELECT @LicenseeId = LicenseeId
	FROM dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeName = @LicenseeName

	IF ISNULL(@SystemName,'') <> '' AND ISNULL(@LicenseeId, 0) <> 0
	BEGIN
		DECLARE @tblSystem AS TABLE (
				SystemId	INT
			,	SystemCode	VARCHAR(10)
			)	

		INSERT INTO @tblSystem (SystemId, SystemCode)
		SELECT 0, val
		FROM CUSTDB.dbo.strSplit(@SystemName, ',')
		
		UPDATE a
		SET a.SystemId = b.id
		FROM @tblSystem a
		INNER JOIN dbo.Systems b WITH (NOLOCK)
		ON a.SystemCode = b.SystemName
		
		--- Set active for all of existing systems  
		UPDATE sl
		SET sl.isActive = 1
		FROM dbo.SystemLicensee sl WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @tblSystem s ON sl.SystemID = s.SystemId
		WHERE sl.LicenseeID = @LicenseeId
		
		--- Set active for all of existing systems  
		INSERT INTO dbo.SystemLicensee (SystemID, LicenseeID, IsActive)
		SELECT s.SystemId, @LicenseeId, 1
		FROM @tblSystem s
		WHERE s.SystemId <> 0 
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.SystemLicensee sl WITH (NOLOCK)
					WHERE sl.LicenseeID = @LicenseeId AND sl.SystemID = s.SystemId)
	
		IF EXISTS (SELECT 1 FROM @tblSystem WHERE SystemId = 0)
		BEGIN
			SELECT @ErrMsg = 'Invalid systems(s): ' + STUFF((
							SELECT ',' + SystemCode
							FROM @tblSystem
							WHERE SystemId = 0
						FOR XML PATH('')), 1, 1, '')
		END	
	END
	ELSE
	BEGIN
		SET @ErrMsg = 'Licensee is invalid or active system list is empty'
	END
END
GO