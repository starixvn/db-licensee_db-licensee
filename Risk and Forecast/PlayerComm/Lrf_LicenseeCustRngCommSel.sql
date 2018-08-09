
/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_LicenseeCustRngCommSel] 
 @IBCCustID INT,
 @RNGComm decimal(9,8) OUTPUT, 
 @ErrCode INT = 0 OUTPUT,
 @ErrMsg varchar(8000) = '' OUTPUT
AS  
/*  
 * Created: 20131105@Hannah
 * Task : Get customer RNG Casino Commission
 * DB: DBEXT/bodb02
 *  
 * Revisions:   
	20141114@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
	- 20180809@Joseph: Remove table LicenseeCustInfo [RedmineID: #99464]

 * Parameter's Explaination:
  • @IBCCustID: ID of the IBC customer
  • @RNGComm: RNG Casino Commission
  • @ErrCode:
    = 0: Transaction recorded successfully.
    > 0: Specific Error.    
  • @ErrMsg: Error description.		

*/  
BEGIN  
	SET NOCOUNT ON;  
	DECLARE @LicenseeID INT 

	-- get LicenseeID of @IBCCustID
	SELECT TOP 1 @LicenseeID = lc.LicenseeID 
	FROM Customer c WITH (NOLOCK)
		INNER JOIN bodb_licensee.dbo.f_SelLicenseeCust(0) lc ON lc.CustID = c.recommend AND c.roleid = 1
			WHERE c.custID = @IBCCustID

	SET @RNGComm = 0
	IF ISNULL(@LicenseeID,0)>0
	BEGIN 
		DECLARE @IsAllowedMemberComm BIT, @IsAllowProduct INT
		-- @IsAllowedMemberComm: check whether member commission is enabled on the Licensee that the customer belongs to or not
		-- @IsAllowProduct: check whether the RNG Casino commission is enable on the Licensee that the customer belongs to or not 
		SELECT @IsAllowedMemberComm= IsAllowedMemberComm FROM bodb_licensee.dbo.Licensees  WITH (NOLOCK)
			WHERE LicenseeID = @LicenseeID 
  
		SELECT @IsAllowProduct= COUNT(1)
		FROM bodb_licensee.dbo.LicenseeProduct3rd lp  WITH (NOLOCK)
			LEFT JOIN bodb_licensee.dbo.Product3rd p  WITH (NOLOCK) ON lp.ProductID = p.ProductID
				WHERE p.ProductName = 'RNG Casino' AND lp.LicenseeID = @LicenseeID 
  
		IF (@IsAllowedMemberComm =0) OR (ISNULL(@IsAllowProduct,0)=0) 
		BEGIN 
			SELECT @ErrMsg = 'Member commission is not enabled for this licensee!' , @ErrCode = 101       
			RETURN
		END

		IF NOT EXISTS(
			SELECT * 
			FROM bodb02.dbo.Customer c WITH (NOLOCK)
				INNER JOIN bodb_licensee.dbo.LicenseeCustComm cc WITH (NOLOCK) ON c.custid = cc.custid 
					AND cc.Licenseeid=@LicenseeID AND cc.CustID =@IBCCustID
		)
		BEGIN
			SELECT @ErrMsg ='Customer does not exist!', @ErrCode = 102 
			RETURN
		END
		ELSE
		BEGIN
			SELECT @RNGComm=ISNULL (RNGComm,0) 
			FROM bodb_licensee.dbo.LicenseeCustComm cc WITH (NOLOCK)
				WHERE cc.LicenseeID = @LicenseeID AND cc.CustID =@IBCCustID
		END  
	END
	ELSE
	BEGIN
		SELECT @ErrMsg = 'Customer does not exist!' , @ErrCode = 102       
		RETURN
	END
END
GO