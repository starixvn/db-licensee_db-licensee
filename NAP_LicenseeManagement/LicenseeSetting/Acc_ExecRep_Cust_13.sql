ALTER PROCEDURE [dbo].[Acc_ExecRep_Cust_13]
	@ids VARCHAR(MAX)
	,@Sporttype INT
	,@Bettype INT = 0
	,@MaxPerMatch MONEY
	,@MaxPerBall MONEY = 0
	,@ExistedMember BIT
	,@Enable BIT = 0 
	,@EnableDownline BIT = 0
AS
/*
	Created: Daniel
	Date: 20150613
	Task : Licensee Setting Configuration - Update Bet Setting - max per match
	DB: DBCUST/CustDB
	Original:

	Revisions:
 	- 20150613@Daniel: 
 	    + Created, split update custinfo part in SP Acc_CustSetting3rd_11 into this SP for separate custDB to new server DBCUST
	    + Improve medthod check table existing in subscribers		

	Param's Explanation:
		
*/ 
BEGIN

	SET NOCOUNT ON
	
	IF(dbo.f_CheckRepTable('custinfo') = 0) RETURN
	
	
	DECLARE @string VARCHAR(MAX), @splitter CHAR(1), @xml XML
	SELECT @splitter = ',', @string = @ids

	SET @xml = N'<root><r i=''' + REPLACE(@string, @splitter, '''/><r i=''') + '''/></root>'

	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust (custid INT)	
	INSERT INTO #tblCust(custid)
	SELECT r.value('./@i','INT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)

	IF @Sporttype IN (1,2,3,5,8,10,11,99,154) --Sportbook
	BEGIN
		IF @ExistedMember = 0
		BEGIN
			IF @Sporttype = 1
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 2
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch2 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 3
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch3 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 5
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch5 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 8
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch8 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 10
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch10 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 11
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch11 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 99 AND @Bettype = 1
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch99 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 99 AND @Bettype = 9
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch99MP = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 154
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch154 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
		END		
		ELSE
		BEGIN
			IF @Sporttype = 1
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 2
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch2 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 3
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch3 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 5
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch5 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 8
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch8 =	@MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 10
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch10 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 11
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch11 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 99 AND @Bettype = 1
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch99 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 99 AND @Bettype = 9
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch99MP = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 154
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch154 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
		END
		
	END

	IF @Sporttype = 161 --NumberGame
	BEGIN	
		IF @ExistedMember = 0
		BEGIN
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET maxpermatch161 = @MaxPerMatch,
				MaxPerBall161 = @MaxPerBall
			WHERE custid IN (SELECT custid FROM #tblCust) 
				AND roleid <> 1


		END
		ELSE
		BEGIN
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET maxpermatch161 = @MaxPerMatch,
				MaxPerBall161 = @MaxPerBall
			WHERE custid IN (SELECT custid FROM #tblCust) 


		END				
	END 

	IF @Sporttype BETWEEN 151 AND 153 --Racing
	BEGIN		
		IF @Enable = 1 AND @EnableDownline = 0
		BEGIN
			IF @Sporttype = 151 AND @Bettype = 31
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET DisableHorseracing = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 151 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET DisableOpenTote = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 151 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable151_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 152 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable152_UK = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 152 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable152_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1
			
			ELSE IF @Sporttype = 153 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable153_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1							
		END
		
		IF @Enable = 1 AND @EnableDownline = 1
		BEGIN
			IF @Sporttype = 151 AND @Bettype = 31
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET DisableHorseracing = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 151 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET DisableOpenTote = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 151 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable151_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 152 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable152_UK = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 152 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable152_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
			
			ELSE IF @Sporttype = 153 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET Disable153_AU = 0					
				WHERE custid IN (SELECT custid FROM #tblCust) 
		END

		IF @ExistedMember = 0
		BEGIN
			IF @Sporttype = 151 AND @Bettype = 31
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 151 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151_OT = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 151 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 152 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch152_UK = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 152 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch152_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 153 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch153_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1		
		
		END
		ELSE
		BEGIN
			IF @Sporttype = 151 AND @Bettype = 31
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 151 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151_OT = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 151 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch151_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 152 AND @Bettype = 41
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch152_UK = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 152 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch152_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 153 AND @Bettype = 51
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  MaxPerMatch153_AU = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
		END
	END 

	IF @Sporttype BETWEEN 180 AND 186 --Virtual sport
	BEGIN		

		IF @Enable = 1 AND @EnableDownline = 0
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET  DisableVirtualSports = 0
				,HideVirtualSports = 0
			WHERE custid IN (SELECT custid FROM #tblCust) 
				AND roleid <> 1
		
		IF @Enable = 1 AND @EnableDownline = 1
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET  DisableVirtualSports = 0
				,HideVirtualSports = 0
			WHERE custid IN (SELECT custid FROM #tblCust) 

		IF @ExistedMember = 0
		BEGIN
			IF @Sporttype = 180
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch180 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 181
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch181 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 182
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch182 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 183
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch183 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 184
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch184 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 185
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch185 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

			ELSE IF @Sporttype = 186
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch186 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 
					AND roleid <> 1

		END
		ELSE
		BEGIN
			IF @Sporttype = 180
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch180 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 181
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch181 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 182
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch182 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 183
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch183 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 184
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch184 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 185
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch185 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 

			ELSE IF @Sporttype = 186
				UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
				SET  maxpermatch186 = @MaxPerMatch
				WHERE custid IN (SELECT custid FROM #tblCust) 	
		END				
	END 

	IF @Sporttype = 202 --Keno
	BEGIN
		IF @Enable = 1 AND @EnableDownline = 0
		BEGIN
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET  HideKeno = 0 
			WHERE custid IN (SELECT custid FROM #tblCust) 
				AND roleid <> 1

		END

		IF @Enable = 1 AND @EnableDownline = 1
		BEGIN
			UPDATE Custinfo WITH(UPDLOCK,ROWLOCK)
			SET  HideKeno = 0 
			WHERE custid IN (SELECT custid FROM #tblCust) 
		END
	END
	DROP TABLE #tblCust
END




