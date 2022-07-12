/*<info serverAlias="DBCUST-CUSTDB" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Lrf_ProblemAccount_LicenseeVipPlayerUpd
	@AgentList VARCHAR(MAX),
	@Username VARCHAR(MAX)= '',
	@IsVip	BIT,
	@UserID INT,
	@IP	VARCHAR(15) = '',
	@Username2 VARCHAR(MAX) = ''
AS
	/*
		Created: 20200213@Johnson
		Task: Problem Account - Licensee VIP player 
		DB: DBCUST/CUSTDB
		
		Revisions:
			- 20200213@Johnson: initial sp [redmine:#128077]
			- 20200417@Elodie: Unremove VIP if void abnormal [Redmine: #132736]
			- 20200605@Eden:LAP - Upload VIP list by ExternalID #135410
			- 20201209@Winfred: Check BA when turn on VIP player [redmine:#146508]
			- 20220602@Johnson: remove ProblemAccount [redmine:#173357]
			- 20220613@Elodie: DBCUST - modify sp syntax to adapt with the SQL Server upgrade to 2019 [Redmine: #171831]  
			- 20220624@Eden: LAP - Segmentation - Rework on Upload File [Redmine: #174132] 

		Paramter's Explanations:	
			- @result:
				ErrCode =
						100: invalid SystemID
						101: dont change status SystemID
						102: dont set vip status coz of void tickets
						0: total accounts update successfully 
						1000: Invalid parameter.
						103: invalid ExternalID
						104: dont change status ExternalID
						105: dont change BA Player

		exec Lrf_ProblemAccount_LicenseeVipPlayerUpd_XTEST
	     @AgentList='<ROOT><Agent AgentId="31607889" Currency="2"/></ROOT>'
		--,@Username='SPONUUS01462,SPONUUS01469,SPONUUS014697,MARSRMB01011,MARSRMB01086'
		,@Username2='amytest11,william2232018a,william2232018aaa,PTEST6,PMOACC3'
		,@IsVip = 0
		,@UserID=338
		,@IP='10.18.200.204'
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, @endRun DATETIME, @duration INT
	SET @startRun = GETDATE()
	
	CREATE TABLE #tblCust (custid INT, 
							username VARCHAR(30), 
							isVip BIT, 	
							isBA BIT, 					
							isLog BIT DEFAULT 0, 
							isUpdate BIT DEFAULT 0,						
							username2 VARCHAR(50),
							Full_username2 VARCHAR(50)
							)
	CREATE TABLE #tblCust2 (custid INT, 
							isVip BIT, 	
							isBA BIT, 					
							isLog BIT DEFAULT 0, 
							isUpdate BIT DEFAULT 0,						
							)

	CREATE TABLE #TempAg (custid INT)

	DECLARE @Result TABLE(ErrCode INT,cnt INT, ErrMsg VARCHAR(MAX))
	DECLARE @DocHandler INT
			,@custList VARCHAR(MAX)
			,@ErrMsg VARCHAR(MAX)
			,@cnt INT
	DECLARE @Site varchar(10)

	IF ISNULL(@username,'')<> '' AND ISNULL(@username2,'')<> ''
	BEGIN 
		SELECT ErrCode = 1000
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END
			
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@AgentList
	
		INSERT INTO #TempAg(CustId)
		SELECT AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId [int], Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 1000
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	IF @Username2 <> ''
	BEGIN
		SELECT TOP (1) @Site = ci.Site 
		FROM #TempAg t
			INNER JOIN customer ci WITH(NOLOCK) ON  ci.custid = t.custid

		INSERT INTO #tblCust(username2,Full_username2)
		SELECT DISTINCT value, @site +  '$' + value
		FROM string_split(@username2,',')
		WHERE value <> ''
	
		UPDATE t
		SET t.custid = ci.custid
		FROM #tblCust t
			INNER JOIN customer ci WITH(NOLOCK)
				ON t.Full_username2 = ci.username2 
			INNER JOIN #TempAg a 
				ON ci.recommend = a.custid
		WHERE ci.roleid = 1
	END

	IF @Username <> ''
	BEGIN
		INSERT INTO #tblCust(username)
		SELECT DISTINCT value
		FROM string_split(@username,',')
		WHERE value <> '' 

		UPDATE t
		SET t.custid = ci.custid
		FROM #tblCust t
			INNER JOIN customer ci WITH(NOLOCK)
				ON t.username = ci.username 
			INNER JOIN #TempAg a 
				ON ci.recommend = a.custid
		WHERE ci.roleid = 1
	END

	IF EXISTS (SELECT 1 FROM #tblCust WHERE custid IS NULL)
	BEGIN	
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username + ','
		FROM #tblCust
		WHERE custid IS NULL
			AND username IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--invalid accounts by Username
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 100,@cnt,@ErrMsg

		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username2 + ','
		FROM #tblCust
		WHERE custid IS NULL
			AND username2 IS NOT NULL
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--invalid accounts by Username2
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 103,@cnt,@ErrMsg
	END
	
	UPDATE t
	SET t.isVip = CASE WHEN d.custid IS NULL THEN 0 ELSE 1 END 
	FROM #tblCust t
		LEFT JOIN Dep_CustVIP d WITH(NOLOCK) ON t.custid = d.custid
	
	IF EXISTS (SELECT 1 FROM #tblCust WHERE isVip = @isVip AND custid IS NOT NULL)
	BEGIN	
		--By UserName
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username + ','
		FROM #tblCust
		WHERE isVip = @isVip
			AND custid IS NOT NULL	
			AND username IS NOT NULL	
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--no change vip status
		IF @cnt > 0
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 101,@cnt,@ErrMsg

		--By UserName2
		SELECT @ErrMsg = ''
		
		SELECT @ErrMsg = @ErrMsg + username2 + ','
		FROM #tblCust t
		WHERE isVip = @isVip
			AND custid IS NOT NULL		
			AND username2 IS NOT NULL
			AND NOT EXISTS( SELECT 1 
							FROM #tblCust t2
							WHERE t2.isVip = @isVip
								AND t.custid =t2.custid
								AND t2.username IS NOT NULL )
		
		SELECT @cnt = @@ROWCOUNT
		
		SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
		
		--no change vip status
		IF @cnt > 0 
			INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
			SELECT 104,@cnt,@ErrMsg
	END
	
	IF @IsVip = 1
	BEGIN
		--Check BA
		UPDATE t
		SET t.isBA = CASE WHEN b.custid IS NULL THEN 0 ELSE 1 END 
		FROM #tblCust t
			LEFT JOIN Dep_CustBAActive b WITH(NOLOCK) ON t.custid = b.custid
		
		IF EXISTS (SELECT 1 FROM #tblCust WHERE isBA = 1 AND custid IS NOT NULL)
		BEGIN	
			--By UserName
			SELECT @ErrMsg = ''
			
			SELECT @ErrMsg = @ErrMsg + username + ','
			FROM #tblCust
			WHERE isBA = 1
				AND custid IS NOT NULL	
				AND username IS NOT NULL	
			
			SELECT @cnt = @@ROWCOUNT
			
			SELECT @ErrMsg = REVERSE(SUBSTRING(REVERSE(@ErrMsg),2,LEN(@ErrMsg)))
			
			--no update BA player
			IF @cnt > 0
				INSERT INTO @Result(ErrCode,Cnt,ErrMsg)
				SELECT 105,@cnt,@ErrMsg
	
		END
	END 
	
	--> Distinct custid to update and write log
	INSERT INTO #tblCust2(custid,isLog,isUpdate,isVip,isBA)
	SELECT DISTINCT custid,t.isLog,t.isUpdate,t.isVip,t.isBA
	FROM #tblCust t

	IF NOT EXISTS(SELECT 1 FROM #tblCust2 
				WHERE isVip <> @isVip 
					AND custid IS NOT NULL)
	BEGIN				
		SELECT * FROM @Result
		
		RETURN;
	END
	
	IF @isVip = 1 AND NOT EXISTS(SELECT 1 FROM #tblCust2 WHERE isVip <> @isVip AND isBA = 0)
	BEGIN
		SELECT * FROM @Result
		RETURN;
	END
	
	
	WHILE(1=1)
	BEGIN
		SELECT @custList = ''
		IF @isVip = 1
		BEGIN
			UPDATE TOP (5000) t
			SET @custList = @custList + CAST(custid AS VARCHAR(10)) + ',',
				isUpdate = 1
			FROM #tblCust2 t
			WHERE isVip <> @isVip
				AND isBA = 0
				AND isUpdate = 0
				AND custid IS NOT NULL
		END
		ELSE
		BEGIN
			UPDATE TOP (5000) t
			SET @custList = @custList + CAST(custid AS VARCHAR(10)) + ',',
				isUpdate = 1
			FROM #tblCust2 t
			WHERE isVip <> @isVip
				AND isUpdate = 0
				AND custid IS NOT NULL
			
		END 
		
		
		SELECT @cnt = @@ROWCOUNT
				
		EXEC Acc_CustomerInfo_Execrep_03 
			@CustList = @custList,
			@UserID = @UserID,
			@isVip = @isVip,
			@mode = 'VIPStatus'

		IF @cnt < 5000
			BREAK;
	END
	
	--total customer update successfully
	INSERT INTO @Result(ErrCode,Cnt, ErrMsg)
	SELECT 0, count(1),''
	FROM #tblCust2
	WHERE isUpdate = 1
	
	--write log
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())

	-- Write log
	DECLARE @LogData VARCHAR(500),
			@LogData_Old VARCHAR(500),			
			@custid INT
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP (1) t
		SET isLog = 1,
			@custid = custid
		FROM #tblCust2 t
		WHERE isLog = 0
			AND isUpdate = 1
		
		IF @@ROWCOUNT = 0
			BREAK;

		SELECT  @LogData = '<R'							
							+ ' IsVip="' + COALESCE(CAST(@IsVip AS VARCHAR(10)), SPACE(1)) + '"'
							+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
							+ ' />'	
							
		SELECT  @LogData_old = '<R'
								+ ' IsVip="' + COALESCE(CAST(CASE WHEN @IsVip = 1 THEN 0 ELSE 1 END AS VARCHAR(10)), SPACE(1)) + '"'
								+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
								+ ' />'
							
		EXEC dbo.Acc_WriteLog_UserLog_RunSP_Wrapper
				@UserId				= @UserId,
				@CustID				= @custid,		
				@ActionId			= 31625,
				@TrackingValue		= @LogData,
				@TrackingValue2		= @LogData_Old,
				@Duration			= @Duration
	END		
	
	SELECT * FROM @Result

	DROP TABLE #tblCust
	DROP TABLE #tblCust2
	DROP TABLE #TempAg
END	
GO