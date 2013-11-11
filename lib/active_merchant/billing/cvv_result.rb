module ActiveMerchant
  module Billing
    # Result of the Card Verification Value check
    # http://www.bbbonline.org/eExport/doc/MerchantGuide_cvv2.pdf
    # Check additional codes from cybersource website
    class CVVResult

      MESSAGES = {
        'D'  =>  'Suspicious transaction',
        'I'  =>  'Failed data validation check',
        'M'  =>  'Match',
        'N'  =>  'No Match',
        'P'  =>  'Not Processed',
        'S'  =>  'Should have been present',
        'U'  =>  'Issuer unable to process request',
        'X'  =>  'Card does not support verification'
      }

      DATACASH_MESSAGES = {
        'matched'      =>  'Match',
        'notmatched'   =>  'No Match',
        'partialmatch' =>  'Partial Match',
        'notprovided'  =>  'Not Processed',
        'notchecked'   =>  'Not Checked'
      }

      def self.messages
        MESSAGES
      end

      attr_reader :code, :message

      def initialize(code, datacash=false)
        if datacash
          @code = code
          @message = DATACASH_MESSAGES[@code]
        else
          @code = code.upcase unless code.blank?
          @message = MESSAGES[@code]
        end
      end

      def to_hash
        {
          'code' => code,
          'message' => message
        }
      end
    end
  end
end
