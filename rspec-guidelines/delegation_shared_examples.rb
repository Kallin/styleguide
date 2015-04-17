shared_examples_for "a class method delegation" do |message|
  let(:call_class_method)  { subject.class.send(message) }
  specify "subject delegates #{message} to subject.class.regional_delegate" do
    subject.class.regional_delegate.expects(message)
    call_class_method
  end
end

shared_examples_for "an instance method delegation" do |message|
  let(:call_instance_method) { subject.send(message) }
  specify "subject delegates #{message} to subject.regional_delegate" do
    subject.regional_delegate.expects(message)
    call_instance_method
  end
end
