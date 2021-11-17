/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BA_SpecialCustSearch]
	(
		@LicenseeID  INT =NULL,
		@Str VARCHAR(MAX)=NULL,
		@NumRow     INT=50,
		@ErrCode	INT = 0 OUTPUT,		
		@ErrMsg		varchar(1000)='' OUTPUT 
	)
AS
/*
Created: Jim
Date: 5-03-2012
Task : Replace hardcode member spread by web application
DB: DB052.bodb_Licensee
Original:

Revisions:
	- 20120417@Henry: enhance performance
	- 20180809@Sophia: HA - remove LicenseeCustInfo table [Redmine: #99464]
Param's Explanation:
	
*/
BEGIN

	DECLARE @tmpCustomerList   AS TABLE (ID int IDENTITY(1,1),strvalue char(50))
	INSERT INTO @tmpCustomerList(strvalue) SELECT LTRIM(RTRIM(VAL))  FROM strSplit(@str,',')
	/*
	 --- in case @LicenseeID =null --->get all data
	IF NOT EXISTS (SELECT 1 FROM  strSplit(@str,','))
	BEGIN
		INSERT INTO @CustomerList(strvalue) SELECT NULL
	END
	*/
	DECLARE @tmpCust AS TABLE (ID INT IDENTITY (1,1),CustID INT ,SystemID VARCHAR(50),ExternalID VARCHAR(50),ugroup VARCHAR(3),BAStatus VARCHAR(10))
	INSERT INTO @tmpCust(CustID,SystemID ,ExternalID ,ugroup,BAStatus)
	SELECT   TOP 50 c.CustID,c.username SystemID, 
				SUBSTRING(c.username2,  CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) As ExternalID,
				c.ugroup,
			 CASE WHEN ISNULL(lb.Custid,0)=0 THEN 'OFF' ELSE 'ON' END BAStatus 	
	FROM   bodb02.dbo.Customer c (NOLOCK)  
	INNER JOIN LicenseeCust lc (NOLOCK) ON lc.CustID=c.recommend
	LEFT JOIN LicenseeBAHistory lb (NOLOCK) ON lb.LicenseeID=@LicenseeID AND lb.CustID=c.CustID AND lb.Status='Running'
	WHERE c.username IN (SELECT ISNULL(strvalue,c.username) FROM @tmpCustomerList)
	AND c.roleid = 1
	AND lc.LicenseeID = @LicenseeID
	
	UPDATE @tmpCust 
	SET ugroup=b.ugroup
	FROM  @tmpCust a
	INNER JOIN licenseeSpecialCust b ON a.CustID=b.CustID
	
	SELECT @ErrCode=ID FROM @tmpCust
	IF ISNULL(@ErrCode,0)=0
		BEGIN
			SELECT @ErrMsg='No customer found',@Errcode=1
			RETURN
		END 
	ELSE 
		BEGIN
			DECLARE @maxList INT,@maxCust INTEGER,@i INT ,@maxNOTFOUND INT,@LicenseeName VARCHAR(50),@UserName VARCHAR(50),@mess VARCHAR(MAX)
				SELECT @maxList=COUNT(1) FROM @tmpCustomerList
				SELECT @maxCust=COUNT(1) FROM @tmpCust
			IF (@maxCust<@maxList)
			BEGIN
				SELECT @LicenseeName=LicenseeName FROM Licensees (NOLOCK) WHERE LicenseeID=@LicenseeID
				SELECT @i=1
				SELECT @mess=''
				DECLARE @tmpNotFoundCust AS TABLE(ID INT IDENTITY(1,1),Username VARCHAR(50))
				INSERT INTO @tmpNotFoundCust (Username)
				SELECT tmpl.strvalue
				FROM @tmpCustomerList tmpl
				WHERE tmpl.strvalue NOT IN (SELECT SystemID FROM @tmpCust)
				
				SELECT @maxNOTFOUND=MAX(ID) FROM @tmpNotFoundCust 
				WHILE (@i<=@maxNOTFOUND)
					BEGIN
						SELECT @UserName=UserName FROM @tmpNotFoundCust WHERE ID=@i
						IF (ISNULL (@mess,'')='')
							SELECT @mess='These customers do not belong to '+@LicenseeName+':'+RTRIM(LTRIM(@Username))+','+space(1)
						ELSE 
							SELECT @mess=@mess+RTRIM(LTRIM(@Username))+','+space(1)
						SET @i=@i+1
					END
				SELECT @ErrMsg=@mess,@Errcode=0
			END
			SELECT kq.SystemID,kq.ExternalID,kq.Ugroup ,kq.BAStatus
		    FROM @tmpCust kq 
			
		END
END
GO 




