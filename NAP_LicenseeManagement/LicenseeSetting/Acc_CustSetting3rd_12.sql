ALTER PROCEDURE [dbo].[Acc_CustSetting3rd_12]
	@ids VARCHAR(MAX)
	,@Sporttype INT
	,@ptVALUE MONEY
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
	
	DECLARE @string VARCHAR(MAX), @splitter CHAR(1), @xml XML
	SELECT @splitter = ',', @string = @ids

	SET @xml = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	--Create temp table containing all accounts belong to super, exclude fincance account
	CREATE TABLE #tblCust (custid INT)
	INSERT INTO #tblCust(custid)
	SELECT r.value('.','INT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)

	IF @Sporttype = 1 --Sportbook
	BEGIN
		UPDATE cs WITH(UPDLOCK,ROWLOCK)
		SET    cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
			  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
			  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 			 
		FROM Dep_CustSetting cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE c.custid IN (SELECT custid FROM #tblCust)
	END

	ELSE IF @Sporttype = 161 --NumberGame
	BEGIN		
		UPDATE cs WITH(UPDLOCK,ROWLOCK)
		SET    cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
			  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
			  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 			 
		FROM Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = 161
			AND c.custid IN (SELECT custid FROM #tblCust)
	END 

	ELSE IF @Sporttype = 180 --Virtual sport
	BEGIN		
		UPDATE cs WITH(UPDLOCK,ROWLOCK)
		SET    cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
			  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
			  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 			 
		FROM Dep_CustSetting3rd cs 
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype BETWEEN 180 AND 186
			AND c.custid IN (SELECT custid FROM #tblCust)
	END 

	ELSE IF @Sporttype = 202 OR @Sporttype = 162 --Keno, Live Casino
	BEGIN
		UPDATE cs WITH(UPDLOCK,ROWLOCK)
		SET	   cs.spositiontaking = case when roleid = 4 then @ptVALUE else 0 end 
			  ,cs.mpositiontaking = case when roleid in (4,3)  then @ptVALUE else 0 end 
			  ,cs.apositiontaking = case when roleid = 3  then 0 else @ptVALUE end 
		FROM CustSettingGame cs
			INNER JOIN CustInfo c ON c.custid = cs.custid
		WHERE cs.Sporttype = @Sporttype
			AND c.custid IN (SELECT custid FROM #tblCust)
	END

	DROP TABLE #tblCust
END




