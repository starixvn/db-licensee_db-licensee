ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_12]
	@srecommend INT
	,@Sporttype INT
	,@ptVALUE MONEY
	,@ErrCode INT = 0 OUTPUT
    ,@ErrMsg NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: Elodie
	Date: 20150108
	Task : Licensee Setting Configuration - Update PT [#6304]
	DB: DBCUST/CustDB
	Original:

	Revisions:

	Param's Explanation:
		@Sporttype: 1 = Sportbook
					161 = Number Game
					162 = Live Casino
					180 = Virtual sports
					202 = Keno
*/ 
BEGIN
	SET NOCOUNT ON
	
	IF (SELECT COUNT(1) FROM sys.objects WHERE name IN ('Dep_Custsetting3rd','custinfo','Dep_CustSetting') AND type = 'U') <> 3
		RETURN
	
	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust(custid INT PRIMARY KEY, isfinished BIT DEFAULT(0))
	INSERT INTO #tblCust(custid)
	SELECT custid
	FROM custinfo WITH(NOLOCK)	
	WHERE srecommend = @srecommend
			AND mrecommend NOT IN (SELECT custid FROM custinfo WITH(NOLOCK)
									WHERE srecommend = @srecommend AND username LIKE '%Acc%' AND roleid=3)

	BEGIN TRY
		DECLARE @rowcnt INT
		WHILE (1=1)
		BEGIN
			UPDATE TOP (4000) #tblCust
			SET isfinished = 1
			FROM #tblCust
			WHERE isfinished = 0

			SELECT @rowcnt = @@rowcount

			IF @Sporttype = 1 --Sportbook
			BEGIN
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET    cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
					  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
					  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 			 
				FROM Dep_CustSetting cs 
					INNER JOIN CustInfo c ON c.custid = cs.custid
					INNER JOIN #tblCust tmp ON c.custid = tmp.custid
			END

			IF @Sporttype = 161 OR @Sporttype = 180 --NumberGame, Virtual sport
			BEGIN		
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET    cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
					  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
					  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 			 
				FROM Dep_CustSetting3rd cs 
					INNER JOIN CustInfo c ON c.custid = cs.custid
					INNER JOIN #tblCust tmp ON c.custid = tmp.custid
				WHERE 1 = CASE	WHEN @Sporttype = 161 AND cs.Sporttype = 161 THEN 1
								WHEN @Sporttype = 180 AND cs.Sporttype BETWEEN 180 AND 186 THEN 1 ELSE 0 END
			END 

			IF @Sporttype = 202 OR @Sporttype = 162 --Keno, Live Casino
			BEGIN
				UPDATE cs WITH(UPDLOCK,ROWLOCK)
				SET	   cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
					  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
					  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 
				FROM CustSettingGame cs
					INNER JOIN CustInfo c ON c.custid = cs.custid
					INNER JOIN #tblCust tmp ON c.custid = tmp.custid
				WHERE cs.Sporttype = @Sporttype
			END

			IF @rowcnt < 4000 BREAK

			WAITFOR DELAY '00:00:01'
		END

		DROP TABLE #tblCust
	END TRY
	BEGIN CATCH
		SELECT @ErrMsg = ERROR_MESSAGE(), @ErrCode  = ERROR_NUMBER()   					
		DROP TABLE #tblCust
		RETURN
	END CATCH	
END





